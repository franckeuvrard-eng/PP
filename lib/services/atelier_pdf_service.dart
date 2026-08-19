import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/activity_type.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';

/// Genere la fiche PDF detaillee d'un atelier : description, objectifs
/// Eduscol, sections ciblees et photos legendees de l'atelier.
///
/// Sert de support a remettre a l'enfant ou aux familles.
class AtelierPdfService {
  static pw.MemoryImage? _imageAt(AppStateProvider provider, String? relPath) {
    final abs = provider.getAbsolutePath(relPath);
    if (abs == null) return null;
    final file = File(abs);
    if (!file.existsSync()) return null;
    try {
      return pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _sectionTitle(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  /// Vignette d'une photo, surmontant sa legende quand elle en a une.
  static pw.Widget _photoTile(pw.MemoryImage image, String? caption) {
    return pw.Container(
      width: 165,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 165,
            height: 124,
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
          ),
          if (caption != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              pdfSafe(caption),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ],
        ],
      ),
    );
  }

  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required ActivityType atelier,
    required PdfPageFormat format,
  }) async {
    final settings = provider.classSettings;
    final space = provider.spaces.firstWhere(
      (s) => s.id == atelier.spaceId,
      orElse: () => Space(id: '', name: 'Non défini', colorHex: '#718096'),
    );

    // La fiche decrit l'atelier seul : les realisations des eleves relevent
    // du rapport individuel, pas de ce support.
    final photoTiles = <pw.Widget>[];
    for (final relPath in atelier.allPhotoPaths) {
      final image = _imageAt(provider, relPath);
      if (image == null) continue;
      photoTiles.add(_photoTile(image, atelier.captionFor(relPath)));
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fiche atelier - A petits pas',
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

            pw.Text(pdfSafe(atelier.name),
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Espace : ${pdfSafe(space.name)}', style: const pw.TextStyle(fontSize: 11)),
            if (atelier.domaine.isNotEmpty)
              pw.Text('Domaine : ${pdfSafe(atelier.domaine)}', style: const pw.TextStyle(fontSize: 11)),
            if (atelier.isObligatory)
              pw.Text(
                atelier.obligatoryGroups.isEmpty
                    ? 'Atelier obligatoire pour toute la classe'
                    : 'Atelier obligatoire pour : ${atelier.obligatoryGroups.map(pdfSafe).join(', ')}',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
              ),
            if (atelier.description != null && atelier.description!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(pdfSafe(atelier.description!),
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
            ],

            if (atelier.objectifs.isNotEmpty) ...[
              _sectionTitle('Objectifs travaillés (${atelier.objectifs.length})'),
              ...atelier.objectifs.map(
                (o) => pw.Bullet(text: pdfSafe(o), style: const pw.TextStyle(fontSize: 10)),
              ),
            ],

            if (photoTiles.isNotEmpty) ...[
              _sectionTitle('Photos de l\'atelier (${photoTiles.length})'),
              pw.Wrap(spacing: 10, runSpacing: 10, children: photoTiles),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Ouvre l'apercu imprimable / partageable de la fiche atelier.
  static void openPreview(
    BuildContext context,
    AppStateProvider provider,
    ActivityType atelier,
  ) {
    final safeName = atelier.name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');

    openPdfViewer(
      context,
      title: 'Fiche - ${atelier.name}',
      fileName: 'Atelier_${safeName.isEmpty ? 'sans_nom' : safeName}.pdf',
      build: (format) => buildBytes(provider: provider, atelier: atelier, format: format),
      shareSubject: 'Fiche atelier - ${atelier.name}',
      shareBody: 'Veuillez trouver ci-joint la fiche détaillée de l\'atelier ${atelier.name}.',
    );
  }
}
