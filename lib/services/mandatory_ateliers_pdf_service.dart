import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/eduscol_data.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'atelier_status_resolver.dart';

/// Genere, pour un ou plusieurs eleves, le plan de travail : les ateliers
/// obligatoires pour leur section avec leur statut courant, de quoi savoir,
/// d'un coup d'oeil, ce qu'il reste a faire.
///
/// Les ateliers sont presentes en vignettes portrait alignees les unes apres
/// les autres (grille), regroupees par domaine : l'espace n'est pas affiche,
/// pour tenir un maximum d'ateliers par page.
class MandatoryAteliersPdfService {
  /// Hauteur fixe d'une vignette. Fixe pour que la grille reste alignee ; le
  /// contenu est borne en consequence (objectifs limites, texte coupe).
  static const double _tileHeight = 224;
  static const double _tileGap = 8;
  static const double _pageMargin = 24;
  static const double _photoHeight = 92;
  static const int _maxObjectives = 3;

  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
  }) async {
    final settings = provider.classSettings;
    final doc = pw.Document();

    // Largeur d'une vignette : on vise ~170 pt, soit 3 colonnes en A4 portrait.
    final usable = format.width - 2 * _pageMargin;
    final columns = ((usable + _tileGap) / (170 + _tileGap)).floor().clamp(2, 6);
    final tileWidth = (usable - _tileGap * (columns - 1)) / columns;

    // Une photo n'est lue et decodee qu'une fois, meme si l'atelier figure sur
    // la page de plusieurs eleves.
    final photos = <String, pw.MemoryImage?>{};
    pw.MemoryImage? photoOf(ActivityType a) => photos.putIfAbsent(a.id, () {
          final rel = a.allPhotoPaths.isEmpty ? null : a.allPhotoPaths.first;
          final abs = provider.getAbsolutePath(rel);
          if (abs == null) return null;
          final file = File(abs);
          if (!file.existsSync()) return null;
          try {
            return pw.MemoryImage(file.readAsBytesSync());
          } catch (_) {
            return null;
          }
        });

    for (final child in children) {
      final mandatory = provider.activityTypes
          .where((a) => a.isObligatoryForGroup(child.group))
          .toList()
        ..sort((a, b) {
          final byDomain = _domainRank(a).compareTo(_domainRank(b));
          if (byDomain != 0) return byDomain;
          final byLabel = a.domaine.compareTo(b.domaine);
          return byLabel != 0 ? byLabel : a.name.compareTo(b.name);
        });

      final rows = <List<ActivityType>>[
        for (var i = 0; i < mandatory.length; i += columns)
          mandatory.sublist(i, min(i + columns, mandatory.length)),
      ];

      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(_pageMargin),
          build: (context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(pdfSafe('${child.firstname} ${child.lastname ?? ''}'.trim()),
                          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        [
                          'Plan de travail',
                          if (child.group != null && child.group!.isNotEmpty) child.group!,
                          settings.name,
                          settings.schoolYear,
                        ].map(pdfSafe).join(' - '),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(thickness: 0.6, color: PdfColors.grey500),
              pw.SizedBox(height: 4),
              if (mandatory.isEmpty)
                pw.Text('Aucun atelier obligatoire configuré pour cette section.',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))
              else
                for (final row in rows)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: _tileGap),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < row.length; i++) ...[
                          if (i > 0) pw.SizedBox(width: _tileGap),
                          _atelierTile(
                            provider: provider,
                            child: child,
                            atelier: row[i],
                            photo: photoOf(row[i]),
                            width: tileWidth,
                          ),
                        ],
                      ],
                    ),
                  ),
            ];
          },
        ),
      );
    }

    return doc.save();
  }

  /// Rang du domaine dans le programme Eduscol (langage, maths, ...) ; les
  /// domaines saisis librement viennent ensuite. L'ordre alphabetique
  /// melangerait les domaines du programme.
  static int _domainRank(ActivityType atelier) {
    final index = EduscolData.domains.indexWhere(
      (d) => d.id == atelier.domaineId || d.title == atelier.domaine,
    );
    return index == -1 ? EduscolData.domains.length : index;
  }

  /// Niveaux (PS / MS / GS) des objectifs Eduscol de l'atelier, dans l'ordre
  /// des classes. Les objectifs saisis librement n'ont pas de niveau.
  static String? _levelsOf(ActivityType atelier) {
    final levels = <String>{};
    for (final text in atelier.objectifs) {
      final match = EduscolData.objectives.where((o) => o.text == text);
      if (match.isNotEmpty && match.first.level != 'Tous') levels.add(match.first.level);
    }
    if (levels.isEmpty) return null;
    const order = ['PS', 'MS', 'GS'];
    return (levels.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)))).join(' / ');
  }

  static PdfColor _color(String hex, PdfColor fallback) {
    try {
      return PdfColor.fromInt(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return fallback;
    }
  }

  /// Vignette portrait d'un atelier pour un eleve : case a cocher (cochee des
  /// que le statut le plus recent est "acquis") et nom, photo, puis domaine,
  /// niveau, objectifs et statut courant.
  static pw.Widget _atelierTile({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
    required pw.MemoryImage? photo,
    required double width,
  }) {
    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final acquis = snapshot.statusId == 'acquis';
    final statusColor = _color(snapshot.colorHex, PdfColors.grey700);
    final accent = _color(atelier.colorHex, PdfColors.grey500);
    final niveau = _levelsOf(atelier);
    final shown = atelier.objectifs.take(_maxObjectives).toList();
    final hidden = atelier.objectifs.length - shown.length;

    return pw.Container(
      width: width,
      height: _tileHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.ClipRect(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(height: 3, color: accent),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 13,
                    height: 13,
                    margin: const pw.EdgeInsets.only(right: 5, top: 0.5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: acquis ? PdfColors.green700 : PdfColors.grey600, width: 1.1),
                      color: acquis ? PdfColors.green700 : PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    ),
                    child: acquis
                        ? pw.Center(
                            child: pw.Text('X',
                                style: pw.TextStyle(
                                    color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          )
                        : null,
                  ),
                  pw.Expanded(
                    child: pw.Text(pdfSafe(atelier.name),
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: pw.Container(
                height: _photoHeight,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: photo != null
                      ? pw.Image(photo, fit: pw.BoxFit.cover)
                      : pw.Center(
                          child: pw.Text(
                            pdfSafe(atelier.name.isEmpty ? '' : atelier.name.substring(0, 1).toUpperCase()),
                            style: pw.TextStyle(fontSize: 28, color: accent, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (atelier.domaine.isNotEmpty)
                    pw.Text(pdfSafe(atelier.domaine),
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  if (niveau != null)
                    pw.Text('Niveau : ${pdfSafe(niveau)}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  for (final o in shown)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 1),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('- ', style: const pw.TextStyle(fontSize: 7)),
                          pw.Expanded(
                            child: pw.Text(pdfSafe(o), maxLines: 2, style: const pw.TextStyle(fontSize: 7)),
                          ),
                        ],
                      ),
                    ),
                  if (hidden > 0)
                    pw.Text('+ $hidden autre${hidden > 1 ? 's' : ''} objectif${hidden > 1 ? 's' : ''}',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: pw.Text(
                pdfSafe(snapshot.label),
                maxLines: 1,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
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
      title: 'Ateliers obligatoires',
      fileName: 'Ateliers_obligatoires_${safeLabel.isEmpty ? 'eleves' : safeLabel}.pdf',
      build: (format) => buildBytes(provider: provider, children: children, format: format),
      shareSubject: 'Ateliers obligatoires - A petits pas',
      shareBody: 'Veuillez trouver ci-joint la liste des ateliers obligatoires.',
    );
  }
}
