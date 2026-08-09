import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';

/// Genere la fiche PDF detaillee d'un atelier : description, objectifs
/// Eduscol, photos de l'atelier, et le detail par eleve avec ses photos.
///
/// Sert de support a remettre a l'enfant ou aux familles.
class AtelierPdfService {
  /// Les polices PDF integrees (Helvetica) ne savent pas rendre les emojis :
  /// sans nettoyage ils apparaissent en caracteres parasites.
  static String _clean(String text) {
    return text
        .replaceAll(
            RegExp(
                r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}|\u{1F900}-\u{1F9FF}|\u{1F1E0}-\u{1F1FF}]',
                unicode: true),
            '')
        .trim();
  }

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

  static pw.Widget _photoGrid(List<pw.MemoryImage> images) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images
          .map((img) => pw.Container(
                width: 150,
                height: 112,
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(img, fit: pw.BoxFit.cover),
                ),
              ))
          .toList(),
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

    final logs = provider.activities.where((l) => l.activityTypeId == atelier.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final atelierImages = atelier.allPhotoPaths
        .map((p) => _imageAt(provider, p))
        .whereType<pw.MemoryImage>()
        .toList();

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
                  pw.Text('Fiche atelier - PetitPas',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.Text(
              '${_clean(settings.name)} - ${_clean(settings.teacher)} - ${_clean(settings.schoolYear)}',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 14),

            pw.Text(_clean(atelier.name),
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Espace : ${_clean(space.name)}', style: const pw.TextStyle(fontSize: 11)),
            if (atelier.domaine.isNotEmpty)
              pw.Text('Domaine : ${_clean(atelier.domaine)}', style: const pw.TextStyle(fontSize: 11)),
            if (atelier.isObligatory)
              pw.Text(
                atelier.obligatoryGroups.isEmpty
                    ? 'Atelier obligatoire pour toute la classe'
                    : 'Atelier obligatoire pour : ${atelier.obligatoryGroups.map(_clean).join(', ')}',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
              ),
            if (atelier.description != null && atelier.description!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(_clean(atelier.description!),
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
            ],

            if (atelier.objectifs.isNotEmpty) ...[
              _sectionTitle('Objectifs travaillés (${atelier.objectifs.length})'),
              ...atelier.objectifs.map(
                (o) => pw.Bullet(text: _clean(o), style: const pw.TextStyle(fontSize: 10)),
              ),
            ],

            if (atelierImages.isNotEmpty) ...[
              _sectionTitle('Photos de l\'atelier (${atelierImages.length})'),
              _photoGrid(atelierImages),
            ],

            _sectionTitle('Réalisations des élèves (${logs.length})'),
            if (logs.isEmpty)
              pw.Text('Aucune activité enregistrée pour cet atelier.',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
            else
              ...logs.map((log) => _buildLogBlock(provider, log)),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildLogBlock(AppStateProvider provider, ActivityLog log) {
    final child = provider.children.firstWhere(
      (c) => c.id == log.childId,
      orElse: () => Child(id: '', firstname: 'Élève supprimé', colorHex: '#718096', avatarText: '?'),
    );

    final logImages = log.photoPaths
        .map((p) => _imageAt(provider, p))
        .whereType<pw.MemoryImage>()
        .toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${_clean(child.firstname)} ${_clean(child.lastname ?? '')}'.trim(),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          if (child.group != null && child.group!.trim().isNotEmpty)
            pw.Text('Section : ${_clean(child.group!)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          if (log.evaluationStatus != null && log.evaluationStatus!.trim().isNotEmpty)
            pw.Text('Évaluation : ${_clean(log.evaluationStatus!)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          if (log.note != null && log.note!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(_clean(log.note!),
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ],
          if (logImages.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _photoGrid(logImages),
          ],
        ],
      ),
    );
  }

  /// Ouvre l'apercu imprimable / partageable de la fiche atelier.
  static void openPreview(
    BuildContext context,
    AppStateProvider provider,
    ActivityType atelier,
  ) {
    final safeName = atelier.name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Fiche - ${atelier.name}'),
            backgroundColor: const Color(0xFF4E9F3D),
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) => buildBytes(provider: provider, atelier: atelier, format: format),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: 'Atelier_${safeName.isEmpty ? 'sans_nom' : safeName}.pdf',
            shareActionExtraSubject: 'Fiche atelier - ${atelier.name}',
            shareActionExtraBody: 'Veuillez trouver ci-joint la fiche détaillée de l\'atelier ${atelier.name}.',
          ),
        ),
      ),
    );
  }
}
