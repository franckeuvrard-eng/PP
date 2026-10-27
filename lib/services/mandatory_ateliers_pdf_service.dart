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

/// Reglages d'un plan de travail (ateliers ou parcours), choisis avant
/// l'export.
class WorkPlanOptions {
  /// Affiche le statut actuel sous le nom.
  final bool showStatus;

  /// Trois cases a cocher a la main sous chaque vignette.
  final bool showCheckboxes;

  /// Statuts a inclure (voir [WorkPlanOptions.keyOf]) ; null : tous.
  final Set<String>? statusKeys;

  /// Parcours a inclure (rapport des parcours) ; null : tous ceux que suit
  /// la section de l'eleve.
  final Set<String>? parcoursIds;

  const WorkPlanOptions({
    this.showStatus = true,
    this.showCheckboxes = true,
    this.statusKeys,
    this.parcoursIds,
  });

  /// Cle de filtre d'un statut : l'identifiant du niveau d'evaluation, ou
  /// [noLog] sans observation (« Jamais fait », ou observation sans niveau).
  static const noLog = 'none';
  static String keyOf(AtelierStatusSnapshot s) =>
      s.statusId == null || s.statusId == 'sans_statut' ? noLog : s.statusId!;
}

/// Plans de travail par eleve, en paysage et en vignettes de meme hauteur :
///  - [buildBytes] : les ateliers des espaces coches « plan de travail » pour
///    la section de l'eleve ;
///  - [buildParcoursBytes] : les etapes des parcours, rapport a part.
class MandatoryAteliersPdfService {
  static const _perRow = 4;
  static const _imageHeight = 118.0;

  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) async {
    final doc = pw.Document();
    for (final child in children) {
      final ateliers = provider.activityTypes
          .where((a) => !a.inProgression && a.isObligatoryForGroup(child.group))
          .toList();
      final bySpace = <String, List<ActivityType>>{};
      for (final a in ateliers) {
        (bySpace[a.spaceId] ??= []).add(a);
      }
      final spaceIds = bySpace.keys.toList()
        ..sort((a, b) => (provider.placeById(a)?.name ?? '').compareTo(provider.placeById(b)?.name ?? ''));

      final groups = <(String, List<pw.Widget>)>[];
      for (final spaceId in spaceIds) {
        final list = bySpace[spaceId]!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final vignettes = <pw.Widget>[
          for (final a in list)
            if (_vignette(provider: provider, child: child, atelier: a, options: options) case final v?) v,
        ];
        if (vignettes.isNotEmpty) groups.add((provider.placeById(spaceId)?.name ?? 'Sans espace', vignettes));
      }

      _addChildPages(
        doc,
        provider,
        format,
        child,
        title: 'Plan de travail',
        groups: groups,
        empty: ateliers.isEmpty
            ? 'Aucun atelier dans le plan de travail de cette section.'
            : 'Aucun atelier ne correspond aux statuts choisis.',
      );
    }
    return doc.save();
  }

  static Future<Uint8List> buildParcoursBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) async {
    final doc = pw.Document();
    for (final child in children) {
      final parcours = provider.progressions
          .where((p) => options.parcoursIds == null
              ? p.concernsGroup(child.group)
              : options.parcoursIds!.contains(p.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final groups = <(String, List<pw.Widget>)>[];
      for (final p in parcours) {
        final steps = provider.ateliersInProgressionOrdered(p.id);
        final vignettes = <pw.Widget>[
          for (final (i, s) in steps.indexed)
            if (_vignette(
              provider: provider,
              child: child,
              atelier: s,
              options: options,
              stepLabel: 'Étape ${i + 1}',
              // Etape validee des qu'elle atteint le seuil du parcours.
              done: AtelierEligibilityService.meetsThreshold(provider, child.id, s.id, p.minStatusId),
            )
                case final v?)
              v,
        ];
        if (vignettes.isNotEmpty) groups.add((p.name, vignettes));
      }

      _addChildPages(
        doc,
        provider,
        format,
        child,
        title: 'Parcours',
        groups: groups,
        empty: parcours.isEmpty
            ? 'Aucun parcours pour cet élève.'
            : 'Aucune étape ne correspond aux statuts choisis.',
      );
    }
    return doc.save();
  }

  /// Pages d'un eleve : en-tete, puis chaque groupe (espace ou parcours).
  /// Le titre d'un groupe et sa premiere ligne de vignettes forment un bloc
  /// insecable : un titre ne reste jamais seul en bas de page.
  static void _addChildPages(
    pw.Document doc,
    AppStateProvider provider,
    PdfPageFormat format,
    Child child, {
    required String title,
    required List<(String, List<pw.Widget>)> groups,
    required String empty,
  }) {
    final settings = provider.classSettings;
    doc.addPage(pw.MultiPage(
      pageFormat: format.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(pdfSafe('$title - ${child.firstname} ${child.lastname ?? ''}'.trim()),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    [
                      if (child.group != null && child.group!.isNotEmpty) 'Section ${child.group}',
                      settings.name,
                      settings.schoolYear,
                    ].map(pdfSafe).join(' - '),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
      build: (context) {
        if (groups.isEmpty) {
          return [pw.Text(empty, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))];
        }
        final out = <pw.Widget>[];
        for (final (name, vignettes) in groups) {
          final rows = _rows(vignettes);
          // Bloc insecable : une Column (et un Container, qui en herite) peut
          // etre coupee entre deux pages par MultiPage.
          out.add(pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
                  child: pw.Text(pdfSafe(name), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ),
                rows.first,
              ],
            ),
          ));
          out.addAll(rows.skip(1));
        }
        return out;
      },
    ));
  }

  /// Lignes de [_perRow] vignettes, chacune insecable.
  static List<pw.Widget> _rows(List<pw.Widget> vignettes) => [
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

  /// Vrai si le statut actuel de l'atelier pour cet eleve fait partie des
  /// statuts retenus.
  static bool includes(AppStateProvider provider, Child child, ActivityType atelier, WorkPlanOptions options) {
    if (options.statusKeys == null) return true;
    final snapshot = AtelierStatusResolver.resolve(provider: provider, childId: child.id, activityTypeId: atelier.id);
    return options.statusKeys!.contains(WorkPlanOptions.keyOf(snapshot));
  }

  /// Hauteur commune de toutes les vignettes d'un export : elle ne depend que
  /// des reglages, jamais du contenu (nombre de photos, longueur du nom).
  static double _height(WorkPlanOptions o, {required bool step}) =>
      _imageHeight + 8 + (step ? 11 : 0) + 28 + (o.showStatus ? 13 : 0) + (o.showCheckboxes ? 30 : 0) + 10;

  /// Vignette d'un atelier (ou d'une etape) pour un eleve, ou null si son
  /// statut n'est pas retenu : toutes les photos, le nom, le statut et trois
  /// cases a cocher selon les reglages ; bordure verte une fois acquis.
  static pw.Widget? _vignette({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
    required WorkPlanOptions options,
    String? stepLabel,
    bool? done,
  }) {
    if (!includes(provider, child, atelier, options)) return null;
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
      height: _height(options, step: stepLabel != null),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: acquis ? PdfColors.green700 : atelierColor, width: acquis ? 2 : 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Toutes les photos, entieres (ou pastille a l'initiale).
          pw.Container(
            height: _imageHeight,
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
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (stepLabel != null)
                  pw.SizedBox(
                    height: 11,
                    child: pw.Text(pdfSafe(stepLabel),
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: atelierColor)),
                  ),
                // Nom sur deux lignes au plus, place reservee meme s'il est court.
                pw.SizedBox(
                  height: 28,
                  child: pw.Text(pdfSafe(atelier.name),
                      maxLines: 2, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
                if (options.showStatus)
                  pw.SizedBox(
                    height: 13,
                    child: pw.Text(pdfSafe(acquis ? '${snapshot.label} - fait !' : snapshot.label),
                        maxLines: 1,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: statusColor)),
                  ),
                if (options.showCheckboxes)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    // Trois passages a cocher a la main, sur la feuille.
                    child: pw.Row(
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

  static String _fileLabel(List<Child> children) {
    final label = children.length == 1 ? children.first.firstname : '${children.length}_eleves';
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');
    return safe.isEmpty ? 'eleves' : safe;
  }

  /// Apercu imprimable / partageable du plan de travail (ateliers).
  static void exportForChildren({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) {
    openPdfViewer(
      context,
      title: 'Plan de travail',
      fileName: 'Plan_de_travail_${_fileLabel(children)}.pdf',
      build: (format) => buildBytes(provider: provider, children: children, format: format, options: options),
      shareSubject: 'Plan de travail - A petits pas',
      shareBody: 'Veuillez trouver ci-joint le plan de travail.',
    );
  }

  /// Apercu imprimable / partageable du plan des parcours.
  static void exportParcoursForChildren({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) {
    openPdfViewer(
      context,
      title: 'Parcours des élèves',
      fileName: 'Parcours_${_fileLabel(children)}.pdf',
      build: (format) =>
          buildParcoursBytes(provider: provider, children: children, format: format, options: options),
      shareSubject: 'Parcours - A petits pas',
      shareBody: 'Veuillez trouver ci-joint les parcours.',
    );
  }
}
