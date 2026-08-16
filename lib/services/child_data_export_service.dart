import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/sons_data.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';

/// Export RGPD (droit d'accès / portabilité) des données d'un élève.
///
/// Distinct du rapport pédagogique existant : celui-ci rassemble toutes les
/// données personnelles brutes (identité, suivi des sons, historique complet
/// des observations) dans un seul document, sans filtre de période.
class ChildDataExportService {
  static void exportChild({
    required BuildContext context,
    required AppStateProvider provider,
    required Child child,
  }) {
    openPdfViewer(
      context,
      title: 'Données RGPD - ${child.firstname}',
      fileName: 'APetitPas_RGPD_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
      build: (format) => _buildBytes(child, provider, format),
      shareSubject: 'Export RGPD - ${child.firstname}',
      shareBody: 'Export des données personnelles conservées par A petit pas pour ${child.firstname}.',
      shareEmails: child.email != null && child.email!.isNotEmpty ? [child.email!] : null,
    );
  }

  static Future<Uint8List> _buildBytes(Child child, AppStateProvider provider, PdfPageFormat format) async {
    final doc = pw.Document();
    final logs = provider.activitiesForChild(child.id).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    pw.MemoryImage? profileImage;
    final profilePath = provider.getAbsolutePath(child.imagePath);
    if (profilePath != null && File(profilePath).existsSync()) {
      profileImage = pw.MemoryImage(File(profilePath).readAsBytesSync());
    }

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Export des données personnelles (RGPD)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          pdfSafe('Toutes ces données sont stockées uniquement sur cet appareil, sans aucun serveur.'),
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Identité', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  _field('Prénom', child.firstname),
                  _field('Nom', child.lastname),
                  _field('Date de naissance', _formatBirthdate(child.birthdate)),
                  _field('Groupe / Section', child.group),
                  _field('Email des parents', child.email),
                  _field('Notes', child.notes),
                  _field('Autorisation droit à l\'image',
                      child.imageAuthorized ? 'Accordée' : 'Non accordée'),
                ],
              ),
            ),
            if (profileImage != null) ...[
              pw.SizedBox(width: 16),
              pw.Container(
                width: 64,
                height: 64,
                decoration: const pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.grey100,
                ),
                child: pw.Image(profileImage, fit: pw.BoxFit.cover),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 16),

        pw.Text('Suivi des sons (état actuel)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Wrap(
          spacing: 10,
          runSpacing: 4,
          children: SonsData.tous.map((son) {
            final statut = provider.sonStatut(child.id, son);
            return pw.Text(pdfSafe('$son : ${statut.libelle}'), style: const pw.TextStyle(fontSize: 9));
          }).toList(),
        ),
        pw.SizedBox(height: 16),

        pw.Text('Historique des observations (${logs.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        if (logs.isEmpty)
          pw.Text(pdfSafe('Aucune observation enregistrée.'), style: const pw.TextStyle(fontSize: 10)),
        ...logs.map((log) {
          final actType = provider.activityTypes.firstWhere(
            (a) => a.id == log.activityTypeId,
            orElse: () => ActivityType(id: '', name: 'Atelier supprimé', spaceId: '', colorHex: ''),
          );
          final space = provider.spaces.firstWhere(
            (s) => s.id == actType.spaceId,
            orElse: () => Space(id: '', name: '', colorHex: ''),
          );
          final captions = log.photoPaths.map((p) => log.captionFor(p)).whereType<String>().toList();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  pdfSafe('${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)} - ${actType.name}'
                      '${space.name.isNotEmpty ? " (${space.name})" : ""}'),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                if (provider.statusLabel(log) != null)
                  pw.Text(pdfSafe('Évaluation : ${provider.statusLabel(log)!}'),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                if (log.note != null && log.note!.isNotEmpty)
                  pw.Text(pdfSafe('Note : ${log.note!}'), style: const pw.TextStyle(fontSize: 9)),
                if (log.photoPaths.isNotEmpty)
                  pw.Text(
                    pdfSafe('${log.photoPaths.length} photo(s) associée(s)'
                        '${captions.isNotEmpty ? " - légendes : ${captions.join(" ; ")}" : ""}'),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
              ],
            ),
          );
        }),
      ],
    ));
    return doc.save();
  }

  static String? _formatBirthdate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  static pw.Widget _field(String label, String? value) {
    if (value == null || value.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(pdfSafe('$label : $value'), style: const pw.TextStyle(fontSize: 10)),
    );
  }
}
