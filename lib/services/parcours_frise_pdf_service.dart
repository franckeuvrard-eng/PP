import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/activity_type.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'atelier_pdf_service.dart';
import 'parcours_progress.dart';

/// Frise d'un parcours a afficher en classe : de grandes cartes numerotees
/// (nom et photo de chaque etape) reliees par des fleches, lisibles de loin
/// pour que les eleves suivent eux-memes ou ils en sont.
///
/// En paysage, quatre cartes au plus par page, reparties egalement : les
/// pages se mettent bout a bout pour former la frise. Sous chaque etape, une zone vide pour les pinces /
/// etiquettes des eleves, ou leurs prenoms deja places a leur etape.
class ParcoursFrisePdfService {
  static const _maxPerPage = 4;

  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required Progression parcours,
    required PdfPageFormat format,
    required bool withNames,
  }) async {
    final steps = provider.ateliersInProgressionOrdered(parcours.id);
    final color = PdfColor.fromInt(int.parse(parcours.colorHex.replaceFirst('#', '0xff')));
    final pageFormat = format.landscape;

    // Prenoms par etape (index steps.length : parcours termine).
    final namesAt = <int, List<String>>{};
    if (withNames) {
      for (final c in ParcoursProgress.childrenFollowing(provider, parcours)) {
        final pos = ParcoursProgress.of(
            provider: provider, parcours: parcours, steps: steps, childId: c.id);
        (namesAt[pos.step] ??= []).add(c.firstname);
      }
    }

    // Cartes de la frise : les etapes puis l'arrivee.
    final cards = <int>[for (var i = 0; i <= steps.length; i++) i];
    // Repartition egale : 5 cartes donnent 3 + 2 plutot que 4 + 1.
    final pageCount = (cards.length / _maxPerPage).ceil();
    final perPage = (cards.length / pageCount).ceil();
    final pages = <List<int>>[];
    for (var i = 0; i < cards.length; i += perPage) {
      pages.add(cards.sublist(i, (i + perPage).clamp(0, cards.length)));
    }

    final doc = pw.Document();
    for (final (pageIndex, pageCards) in pages.indexed) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(pdfSafe(parcours.name),
                          maxLines: 1,
                          style: pw.TextStyle(
                              fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    if (pages.length > 1)
                      pw.Text('${pageIndex + 1} / ${pages.length}',
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, card) in pageCards.indexed) ...[
                      if (i > 0) _arrow(color),
                      pw.Expanded(
                        child: card == steps.length
                            ? _finishCard(color, namesAt[card], withNames)
                            : _stepCard(provider, steps[card], card, color, namesAt[card], withNames),
                      ),
                    ],
                    // Derniere page incomplete : les cartes gardent leur taille.
                    for (var i = pageCards.length; i < perPage; i++) ...[
                      pw.SizedBox(width: 44),
                      pw.Expanded(child: pw.SizedBox()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _arrow(PdfColor color) => pw.Container(
        width: 44,
        alignment: pw.Alignment.center,
        child: pw.Text('>',
            style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold, color: color)),
      );

  static pw.Widget _numberBadge(String label, PdfColor color) => pw.Container(
        width: 64,
        height: 64,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        child: pw.Text(label,
            style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      );

  static pw.Widget _frame(PdfColor color, List<pw.Widget> children) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 3),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: children),
      );

  /// Zone basse d'une carte : prenoms des eleves arrives la, ou cadre vide
  /// pour accrocher pinces et etiquettes.
  static pw.Widget _childrenZone(List<String>? names, bool withNames) {
    final list = names ?? const <String>[];
    return pw.Container(
      height: 120,
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 1.2, style: pw.BorderStyle.dashed),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: withNames && list.isNotEmpty
          ? pw.Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final n in list)
                  pw.Text(pdfSafe(n), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            )
          : pw.SizedBox(),
    );
  }

  static pw.Widget _stepCard(AppStateProvider provider, ActivityType step, int index, PdfColor color,
      List<String>? names, bool withNames) {
    final images = AtelierPdfService.imagesOf(provider, step);
    return _frame(color, [
      _numberBadge('${index + 1}', color),
      pw.SizedBox(height: 8),
      pw.Text(pdfSafe(step.name),
          textAlign: pw.TextAlign.center,
          maxLines: 3,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Expanded(
        // Toutes les photos de l'etape, entieres.
        child: images.isEmpty ? pw.SizedBox() : AtelierPdfService.photoMosaic(images, gap: 6),
      ),
      pw.SizedBox(height: 8),
      _childrenZone(names, withNames),
    ]);
  }

  static pw.Widget _finishCard(PdfColor color, List<String>? names, bool withNames) {
    return _frame(color, [
      _numberBadge('*', color),
      pw.SizedBox(height: 8),
      pw.Text('Bravo !',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Text('Parcours terminé',
          textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 18)),
      pw.Spacer(),
      _childrenZone(names, withNames),
    ]);
  }

  /// Demande le type de frise puis ouvre l'apercu imprimable.
  static Future<void> export({
    required BuildContext context,
    required AppStateProvider provider,
    required Progression parcours,
  }) async {
    final withNames = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Frise à afficher en classe'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: const ListTile(
              leading: Icon(Icons.crop_free),
              title: Text('Frise vierge'),
              subtitle: Text('Une zone vide sous chaque étape pour les pinces ou étiquettes des élèves.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: const ListTile(
              leading: Icon(Icons.people),
              title: Text('Avec les prénoms'),
              subtitle: Text('Chaque élève est placé sous son étape actuelle.'),
            ),
          ),
        ],
      ),
    );
    if (withNames == null || !context.mounted) return;
    final safeName = parcours.name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');
    openPdfViewer(
      context,
      title: 'Frise · ${parcours.name}',
      fileName: 'Frise_${safeName.isEmpty ? 'parcours' : safeName}.pdf',
      build: (format) => buildBytes(
          provider: provider, parcours: parcours, format: format, withNames: withNames),
      shareSubject: 'Frise du parcours ${parcours.name} - A petits pas',
    );
  }
}
