import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'atelier_eligibility_service.dart';
import 'atelier_pdf_service.dart';
import 'atelier_status_resolver.dart';

/// Genere, pour un ou plusieurs eleves, la liste des ateliers obligatoires
/// pour leur section avec leur statut courant : de quoi savoir, d'un coup
/// d'oeil, ce qu'il reste a faire.
class MandatoryAteliersPdfService {
  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
  }) async {
    final settings = provider.classSettings;
    final doc = pw.Document();

    for (final child in children) {
      // Ateliers des espaces coches « plan de travail » pour la section.
      final inSpaces = provider.activityTypes
          .where((a) => !a.inProgression && a.isObligatoryForGroup(child.group))
          .toList();
      // Les parcours ont leur propre page, dans l'ordre de leurs etapes :
      // tous ceux que suit la section de l'eleve.
      final byProgression = <String, List<ActivityType>>{
        for (final p in provider.progressions)
          if (p.concernsGroup(child.group) && provider.ateliersInProgressionOrdered(p.id).isNotEmpty)
            p.id: provider.ateliersInProgressionOrdered(p.id),
      };
      final mandatory = [...inSpaces, for (final l in byProgression.values) ...l];

      final bySpace = <String, List<ActivityType>>{};
      for (final atelier in inSpaces) {
        (bySpace[atelier.spaceId] ??= []).add(atelier);
      }
      final spaceIds = bySpace.keys.toList()
        ..sort((a, b) => (provider.placeById(a)?.name ?? '').compareTo(provider.placeById(b)?.name ?? ''));
      for (final list in bySpace.values) {
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      final progressionIds = byProgression.keys.toList()
        ..sort((a, b) => (provider.placeById(a)?.name ?? '').compareTo(provider.placeById(b)?.name ?? ''));

      List<pw.Widget> header(String title) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$title - A petits pas',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.Text(
              '${pdfSafe(settings.name)} - ${pdfSafe(settings.teacher)} - ${pdfSafe(settings.schoolYear)}',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 14),
            pw.Text(pdfSafe('${child.firstname} ${child.lastname ?? ''}'.trim()),
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (child.group != null && child.group!.isNotEmpty)
              pw.Text('Section : ${pdfSafe(child.group!)}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
          ];

      pw.Widget groupTitle(String id, String fallback) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
            child: pw.Text(pdfSafe(provider.placeById(id)?.name ?? fallback),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          );

      // Page des ateliers d'espaces, toujours presente (meme vide, elle dit
      // qu'il n'y a rien a faire). La page des progressions n'existe que si
      // la section a des jalons obligatoires.
      if (inSpaces.isNotEmpty || byProgression.isEmpty) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            build: (context) => [
              ...header('Plan de travail'),
              if (mandatory.isEmpty)
                pw.Text('Aucun atelier dans le plan de travail de cette section.',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))
              else
                for (final spaceId in spaceIds) ...[
                  groupTitle(spaceId, 'Sans espace'),
                  ..._vignetteRows([
                    for (final atelier in bySpace[spaceId]!)
                      _vignette(provider: provider, child: child, atelier: atelier),
                  ]),
                ],
            ],
          ),
        );
      }

      if (byProgression.isNotEmpty) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            build: (context) => [
              ...header('Plan de travail - Parcours'),
              for (final progressionId in progressionIds) ...[
                groupTitle(progressionId, 'Parcours'),
                ..._vignetteRows([
                  for (final (i, step) in byProgression[progressionId]!.indexed)
                  _vignette(
                    provider: provider,
                    child: child,
                    atelier: step,
                    stepLabel: 'Étape ${i + 1}',
                    // Une etape est cochee des qu'elle atteint le seuil de
                    // passage du parcours, comme sur l'ecran Parcours.
                    done: AtelierEligibilityService.meetsThreshold(provider, child.id, step.id,
                        provider.progressionById(progressionId)?.minStatusId),
                  ),
                ]),
              ],
            ],
          ),
        );
      }
    }

    return doc.save();
  }

  static const _perRow = 3;

  /// Vignettes rangees par lignes de [_perRow] : chaque ligne est un bloc
  /// que la page peut reporter a la suivante (une grille d'un seul tenant ne
  /// se coupe pas entre deux pages).
  static List<pw.Widget> _vignetteRows(List<pw.Widget> vignettes) => [
        for (var i = 0; i < vignettes.length; i += _perRow)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + _perRow; j++) ...[
                  if (j > i) pw.SizedBox(width: 10),
                  pw.Expanded(child: j < vignettes.length ? vignettes[j] : pw.SizedBox()),
                ],
              ],
            ),
          ),
      ];

  /// Vignette d'un atelier (ou d'une etape) pour un eleve : la photo en
  /// grand, le nom, le statut courant (bordure verte une fois acquis, seuil
  /// du parcours pour une etape) et trois cases que l'eleve coche a la main a
  /// chaque passage. La photo dit quoi faire a un enfant qui ne lit pas.
  static pw.Widget _vignette({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
    String? stepLabel,
    bool? done,
  }) {
    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final acquis = done ?? snapshot.statusId == 'acquis';
    final statusColor = _color(snapshot.colorHex);
    final atelierColor = _color(atelier.colorHex);
    final images = AtelierPdfService.imagesOf(provider, atelier);
    final initial = atelier.name.trim().isEmpty ? '?' : atelier.name.trim()[0].toUpperCase();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: acquis ? PdfColors.green700 : atelierColor, width: acquis ? 2 : 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Toutes les photos, entieres (ou pastille a l'initiale). Zone plus
          // haute au-dela de 4 photos pour qu'elles restent lisibles.
          pw.Container(
            height: images.length > 4 ? 170 : 120,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: images.isEmpty ? atelierColor : null,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            alignment: pw.Alignment.center,
            child: images.isNotEmpty
                ? AtelierPdfService.photoMosaic(images)
                : pw.Text(pdfSafe(initial),
                    style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (stepLabel != null)
                  pw.Text(pdfSafe(stepLabel),
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: atelierColor)),
                pw.Text(pdfSafe(atelier.name),
                    maxLines: 2, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(pdfSafe(acquis ? '${snapshot.label} - fait !' : snapshot.label),
                    maxLines: 1,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: statusColor)),
                pw.SizedBox(height: 6),
                // Trois passages a cocher a la main, sur la feuille.
                pw.Row(
                  children: [
                    for (var k = 0; k < 3; k++)
                      pw.Container(
                        width: 22,
                        height: 22,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _color(String hex) {
    try {
      return PdfColor.fromInt(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return PdfColors.grey600;
    }
  }

  /// Ouvre l'apercu imprimable / partageable du rapport, pour un ou plusieurs
  /// eleves (une page par eleve).
  static void exportForChildren({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
  }) {
    final label = children.length == 1
        ? children.first.firstname
        : '${children.length}_eleves';
    final safeLabel = label.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');

    openPdfViewer(
      context,
      title: 'Plan de travail',
      fileName: 'Plan_de_travail_${safeLabel.isEmpty ? 'eleves' : safeLabel}.pdf',
      build: (format) => buildBytes(provider: provider, children: children, format: format),
      shareSubject: 'Plan de travail - A petits pas',
      shareBody: 'Veuillez trouver ci-joint le plan de travail.',
    );
  }
}
