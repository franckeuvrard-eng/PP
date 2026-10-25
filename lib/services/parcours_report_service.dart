import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../utils/file_export.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'parcours_progress.dart';

/// Tableau croise eleves x parcours : pour chaque eleve, l'etape ou il en est
/// dans chaque parcours qu'il suit.
class ParcoursReportService {
  /// Eleves tries par section (ordre des Parametres) puis par prenom.
  static List<Child> _sortedChildren(AppStateProvider provider) {
    final order = provider.sections;
    int rank(Child c) {
      final i = order.indexOf(c.group ?? '');
      return i < 0 ? order.length : i;
    }

    return provider.children.toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase());
      });
  }

  /// Position de l'eleve, ou null s'il ne suit pas le parcours.
  static ParcoursPosition? _position(
      AppStateProvider provider, Progression p, List<ActivityType> steps, Child c) {
    if (!p.concernsGroup(c.group)) return null;
    return ParcoursProgress.of(provider: provider, parcours: p, steps: steps, childId: c.id);
  }

  static String _cellText(ParcoursPosition? pos) {
    if (pos == null) return '-';
    if (pos.total == 0) return '';
    if (pos.finished) return 'Terminé';
    return 'Étape ${pos.step + 1}/${pos.total}\n${pos.current!.name}';
  }

  static Future<Uint8List> buildPdfBytes({
    required AppStateProvider provider,
    required PdfPageFormat format,
  }) async {
    final settings = provider.classSettings;
    final parcours = provider.progressions;
    final steps = {for (final p in parcours) p.id: provider.ateliersInProgressionOrdered(p.id)};
    final children = _sortedChildren(provider);

    PdfColor fill(ParcoursPosition? pos) {
      if (pos == null || pos.total == 0) return PdfColors.grey100;
      if (pos.finished) return PdfColors.green200;
      if (pos.step == 0) return PdfColors.red50;
      return pos.ratio < 0.5 ? PdfColors.orange50 : PdfColors.lightGreen50;
    }

    pw.Widget cell(String text, {PdfColor? color, bool bold = false, pw.TextAlign align = pw.TextAlign.center}) =>
        pw.Container(
          color: color,
          padding: const pw.EdgeInsets.all(4),
          alignment: align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.center,
          child: pw.Text(pdfSafe(text),
              textAlign: align,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : null)),
        );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: format.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Suivi des parcours - A petits pas',
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
          pw.SizedBox(height: 10),
          if (parcours.isEmpty)
            pw.Text('Aucun parcours configuré.', style: const pw.TextStyle(fontSize: 11))
          else ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              defaultColumnWidth: const pw.FlexColumnWidth(),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
              columnWidths: {
                0: const pw.FixedColumnWidth(110),
                1: const pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    cell('Élève', bold: true, align: pw.TextAlign.left),
                    cell('Section', bold: true),
                    for (final p in parcours) cell(p.name, bold: true),
                  ],
                ),
                for (final c in children)
                  pw.TableRow(children: [
                    cell('${c.firstname} ${c.lastname ?? ''}'.trim(), align: pw.TextAlign.left),
                    cell(c.group ?? ''),
                    for (final p in parcours)
                      () {
                        final pos = _position(provider, p, steps[p.id]!, c);
                        return cell(_cellText(pos), color: fill(pos), bold: pos?.finished ?? false);
                      }(),
                  ]),
                // Synthese : combien ont termine chaque parcours.
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Terminé', bold: true, align: pw.TextAlign.left),
                    cell(''),
                    for (final p in parcours)
                      () {
                        final following = children.where((c) => p.concernsGroup(c.group)).toList();
                        final done = following
                            .where((c) => _position(provider, p, steps[p.id]!, c)!.finished)
                            .length;
                        return cell('$done / ${following.length}', bold: true);
                      }(),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '"-" : l\'élève ne suit pas ce parcours (section non concernée). '
              'Une étape est validée quand elle atteint le seuil de passage du parcours.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static void exportPdf({required BuildContext context, required AppStateProvider provider}) {
    openPdfViewer(
      context,
      title: 'Suivi des parcours',
      fileName: 'Suivi_des_parcours.pdf',
      build: (format) => buildPdfBytes(provider: provider, format: format),
      shareSubject: 'Suivi des parcours - A petits pas',
      shareBody: 'Veuillez trouver ci-joint le suivi des parcours de la classe.',
    );
  }

  /// Classeur Excel : une feuille « Tableau » (le meme tableau croise que le
  /// PDF) et une feuille « Données » a plat, une ligne par eleve et par
  /// parcours, prete pour un tableau croise dynamique.
  static Future<void> exportExcel({
    required BuildContext context,
    required AppStateProvider provider,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final parcours = provider.progressions;
      final steps = {for (final p in parcours) p.id: provider.ateliersInProgressionOrdered(p.id)};
      final children = _sortedChildren(provider);

      final excel = xl.Excel.createExcel();
      final table = excel['Tableau'];
      excel.setDefaultSheet('Tableau');
      table.appendRow(<xl.CellValue?>[
        xl.TextCellValue('Élève'),
        xl.TextCellValue('Section'),
        for (final p in parcours) xl.TextCellValue(p.name),
      ]);
      for (final c in children) {
        table.appendRow(<xl.CellValue?>[
          xl.TextCellValue('${c.firstname} ${c.lastname ?? ''}'.trim()),
          xl.TextCellValue(c.group ?? ''),
          for (final p in parcours)
            xl.TextCellValue(_cellText(_position(provider, p, steps[p.id]!, c)).replaceAll('\n', ' - ')),
        ]);
      }

      final data = excel['Données'];
      data.appendRow(<xl.CellValue?>[
        xl.TextCellValue('Élève'),
        xl.TextCellValue('Section'),
        xl.TextCellValue('Parcours'),
        xl.TextCellValue('Étape actuelle (n°)'),
        xl.TextCellValue('Étape actuelle'),
        xl.TextCellValue('Étapes validées'),
        xl.TextCellValue('Nombre d\'étapes'),
        xl.TextCellValue('Terminé'),
      ]);
      for (final c in children) {
        for (final p in parcours) {
          final pos = _position(provider, p, steps[p.id]!, c);
          if (pos == null) continue;
          data.appendRow(<xl.CellValue?>[
            xl.TextCellValue('${c.firstname} ${c.lastname ?? ''}'.trim()),
            xl.TextCellValue(c.group ?? ''),
            xl.TextCellValue(p.name),
            pos.finished ? null : xl.IntCellValue(pos.step + 1),
            xl.TextCellValue(pos.finished ? 'Terminé' : (pos.current?.name ?? '')),
            xl.IntCellValue(pos.step),
            xl.IntCellValue(pos.total),
            xl.TextCellValue(pos.finished ? 'Oui' : 'Non'),
          ]);
        }
      }
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Erreur lors du traitement du fichier Excel.');
      await exportFile(
        fileName: 'APetitPas_Suivi_parcours_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        bytes: bytes,
        mimeType: kXlsxMime,
        subject: 'Suivi des parcours A petits pas (Excel)',
        origin: sharePositionOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'export : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
