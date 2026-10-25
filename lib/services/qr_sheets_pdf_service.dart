import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/activity_type.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'atelier_grouping.dart';

/// Planches de QR codes a imprimer : badges des eleves, etiquettes des
/// ateliers (une ou plusieurs pages par domaine) et des etapes (une ou
/// plusieurs pages par parcours). Les QR des etapes sont ceux d'un atelier :
/// le scan les reconnait de la meme facon.
class QrSheetsPdfService {
  static String childData(String id) => 'PETITPAS:CHILD:$id';
  static String atelierData(String id) => 'PETITPAS:ACT:$id';

  static PdfColor _color(String hex) {
    try {
      return PdfColor.fromInt(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return PdfColors.grey600;
    }
  }

  static pw.Widget _label({
    required String title,
    String? subtitle,
    String? badge,
    required String data,
    required PdfColor color,
    String footer = 'PETITPAS - SCAN',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (badge != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const pw.EdgeInsets.only(bottom: 4),
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(pdfSafe(badge),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          pw.Text(pdfSafe(title),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          if (subtitle != null && subtitle.isNotEmpty)
            pw.Text(pdfSafe(subtitle),
                maxLines: 1,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: data, width: 90, height: 90),
          pw.SizedBox(height: 6),
          pw.Text(footer, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500, letterSpacing: 1)),
        ],
      ),
    );
  }

  static pw.Widget _header(String title, String subtitle, PdfColor color) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(pdfSafe(title),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Text(pdfSafe(subtitle), style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ],
        ),
      );

  /// Une section par page (ou plusieurs si elle deborde) : la section
  /// suivante commence toujours sur une nouvelle page.
  static void _addSection(pw.Document doc, PdfPageFormat format, pw.Widget header, List<pw.Widget> labels) {
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(20),
      header: (_) => header,
      build: (_) => [
        pw.GridView(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: labels,
        ),
      ],
    ));
  }

  static Future<Uint8List> badgesBytes(AppStateProvider provider, PdfPageFormat format) async {
    final doc = pw.Document();
    final children = provider.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    _addSection(
      doc,
      format,
      _header('Badges élèves', provider.classSettings.name, PdfColors.blueGrey700),
      [
        for (final c in children)
          _label(
            title: '${c.firstname} ${c.lastname ?? ''}'.trim(),
            subtitle: c.group ?? '',
            data: childData(c.id),
            color: _color(c.colorHex),
          ),
      ],
    );
    return doc.save();
  }

  /// Etiquettes des ateliers des espaces, une section par domaine.
  static Future<Uint8List> ateliersBytes(AppStateProvider provider, PdfPageFormat format) async {
    final doc = pw.Document();
    final groups = AtelierGrouping.byDomain(provider.activityTypes.where((a) => !a.inProgression));
    for (final group in groups) {
      final color = _color(group.value.first.colorHex);
      _addSection(
        doc,
        format,
        _header(group.key, '${group.value.length} atelier(s)', PdfColors.teal700),
        [
          for (final a in group.value)
            _label(
              title: a.name,
              subtitle: provider.placeOf(a)?.name,
              data: atelierData(a.id),
              color: color,
              footer: 'ATELIER - SCAN',
            ),
        ],
      );
    }
    if (groups.isEmpty) {
      doc.addPage(pw.Page(pageFormat: format, build: (_) => pw.Text('Aucun atelier.')));
    }
    return doc.save();
  }

  /// Etiquettes des etapes, une section par parcours, dans l'ordre du fil.
  static Future<Uint8List> parcoursBytes(
      AppStateProvider provider, List<Progression> parcours, PdfPageFormat format) async {
    final doc = pw.Document();
    for (final p in parcours) {
      final steps = provider.ateliersInProgressionOrdered(p.id);
      final color = _color(p.colorHex);
      _addSection(
        doc,
        format,
        _header(p.name, '${steps.length} étape(s)', color),
        [
          for (final (i, ActivityType s) in steps.indexed)
            _label(
              title: s.name,
              badge: 'Étape ${i + 1}',
              data: atelierData(s.id),
              color: color,
              footer: 'ETAPE - SCAN',
            ),
        ],
      );
    }
    if (parcours.isEmpty) {
      doc.addPage(pw.Page(pageFormat: format, build: (_) => pw.Text('Aucun parcours.')));
    }
    return doc.save();
  }

  static void openBadges(BuildContext context, AppStateProvider provider) => openPdfViewer(
        context,
        title: 'Badges élèves',
        fileName: 'Badges_Eleves_QR.pdf',
        build: (format) => badgesBytes(provider, format),
      );

  static void openAteliers(BuildContext context, AppStateProvider provider) => openPdfViewer(
        context,
        title: 'Étiquettes ateliers',
        fileName: 'Etiquettes_Ateliers_QR.pdf',
        build: (format) => ateliersBytes(provider, format),
      );

  static void openParcours(BuildContext context, AppStateProvider provider, List<Progression> parcours) =>
      openPdfViewer(
        context,
        title: parcours.length == 1 ? 'QR · ${parcours.first.name}' : 'QR des parcours',
        fileName: 'QR_Parcours.pdf',
        build: (format) => parcoursBytes(provider, parcours, format),
      );
}
