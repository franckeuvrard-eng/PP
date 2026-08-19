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
                    padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                    child: pw.Text(pdfSafe(provider.spaceById(spaceId)?.name ?? 'Sans espace'),
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4)},
                    children: [
                      for (final atelier in bySpace[spaceId]!)
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text(pdfSafe(atelier.name), style: const pw.TextStyle(fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text(
                                pdfSafe(
                                  AtelierStatusResolver.resolve(
                                    provider: provider,
                                    childId: child.id,
                                    activityTypeId: atelier.id,
                                  ).label,
                                ),
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
            ];
          },
        ),
      );
    }

    return doc.save();
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
