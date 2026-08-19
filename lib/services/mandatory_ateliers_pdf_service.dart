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
      final mandatory = provider.activityTypes.where((a) => a.isObligatoryForGroup(child.group)).toList();
      final bySpace = <String, List<ActivityType>>{};
      for (final atelier in mandatory) {
        (bySpace[atelier.spaceId] ??= []).add(atelier);
      }
      final spaceIds = bySpace.keys.toList()
        ..sort((a, b) => (provider.spaceById(a)?.name ?? '').compareTo(provider.spaceById(b)?.name ?? ''));

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
                    pw.Text('Ateliers obligatoires - A petits pas',
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

              if (mandatory.isEmpty)
                pw.Text('Aucun atelier obligatoire configuré pour cette section.',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))
              else
                for (final spaceId in spaceIds) ...[
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                    child: pw.Text(pdfSafe(provider.spaceById(spaceId)?.name ?? 'Sans espace'),
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ),
                  for (final atelier in bySpace[spaceId]!)
                    _atelierPlanBlock(
                      provider: provider,
                      child: child,
                      atelier: atelier,
                    ),
                ],
            ];
          },
        ),
      );
    }

    return doc.save();
  }

  /// Bloc "plan de travail" d'un atelier pour un eleve : grande case a
  /// cocher (cochee des que le statut le plus recent est "acquis") suivie
  /// de tout le detail de l'atelier (domaine, description, objectifs) et de
  /// son statut courant, pour que l'eleve/la famille sache exactement quoi
  /// faire et ou il en est.
  static pw.Widget _atelierPlanBlock({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
  }) {
    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final acquis = snapshot.statusId == 'acquis';
    final statusColor = PdfColor.fromInt(int.parse(snapshot.colorHex.replaceFirst('#', '0xff')));

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 24,
            height: 24,
            margin: const pw.EdgeInsets.only(top: 1, right: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: acquis ? PdfColors.green700 : PdfColors.grey600, width: 1.5),
              color: acquis ? PdfColors.green700 : PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: acquis
                ? pw.Center(
                    child: pw.Text('X',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  )
                : null,
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(pdfSafe(atelier.name), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (atelier.domaine.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text('Domaine : ${pdfSafe(atelier.domaine)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ),
                if (atelier.description != null && atelier.description!.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(pdfSafe(atelier.description!.trim()), style: const pw.TextStyle(fontSize: 9)),
                  ),
                if (atelier.objectifs.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  ...atelier.objectifs.map(
                    (o) => pw.Bullet(text: pdfSafe(o), style: const pw.TextStyle(fontSize: 9)),
                  ),
                ],
                pw.SizedBox(height: 4),
                pw.Text(
                  'Statut actuel : ${pdfSafe(snapshot.label)}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
        ],
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
