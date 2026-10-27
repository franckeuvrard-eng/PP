import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/eduscol_data.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/carnet_entry.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import 'atelier_eligibility_service.dart';
import 'atelier_grouping.dart';
import 'atelier_pdf_service.dart';

/// Une reussite ou un apprentissage en cours, pour le carnet.
class CarnetItem {
  final ActivityType atelier;
  final ActivityLog log;
  const CarnetItem(this.atelier, this.log);
}

/// Carnet de suivi des apprentissages (par periode) et synthese des acquis
/// de fin d'ecole maternelle.
class CarnetService {
  static const periods = ['P1', 'P2', 'P3', 'P4', 'P5'];

  /// Dates approximatives des cinq periodes de l'annee scolaire (« 2026-2027 »),
  /// vacances de la zone non connues : l'enseignant peut les ajuster.
  static DateTimeRange periodRange(String schoolYear, String period) {
    final y = int.tryParse(schoolYear.split(RegExp(r'[^0-9]')).first) ??
        (DateTime.now().month >= 8 ? DateTime.now().year : DateTime.now().year - 1);
    final r = switch (period) {
      'P1' => (DateTime(y, 9, 1), DateTime(y, 10, 20)),
      'P2' => (DateTime(y, 10, 21), DateTime(y, 12, 20)),
      'P3' => (DateTime(y, 12, 21), DateTime(y + 1, 2, 15)),
      'P4' => (DateTime(y + 1, 2, 16), DateTime(y + 1, 4, 15)),
      _ => (DateTime(y + 1, 4, 16), DateTime(y + 1, 7, 10)),
    };
    return DateTimeRange(start: r.$1, end: r.$2);
  }

  /// Periode en cours selon la date du jour.
  static String currentPeriod(String schoolYear) {
    final now = DateTime.now();
    for (final p in periods) {
      final r = periodRange(schoolYear, p);
      if (!now.isBefore(r.start) && !now.isAfter(r.end.add(const Duration(days: 1)))) return p;
    }
    return now.month >= 8 ? 'P1' : 'P5';
  }

  /// Domaine du programme d'un atelier (l'ancien « Explorer le monde » va
  /// au domaine « vivant, matiere, objets »).
  static String? domainIdOf(ActivityType a) =>
      a.domaineId == 'd5_monde' ? 'd6_vivant_matiere' : EduscolData.domainById(a.domaineId)?.id;

  static bool _done(AppStateProvider provider, String childId, ActivityType a, ActivityLog log) {
    if (a.inProgression) {
      return AtelierEligibilityService.meetsThreshold(
          provider, childId, a.id, provider.progressionById(a.progressionId)?.minStatusId);
    }
    final statuses = provider.evaluationStatuses;
    return statuses.isNotEmpty && log.evaluationStatusId == statuses.last.id;
  }

  /// Reussites et apprentissages en cours de l'eleve sur la periode, par
  /// domaine : la derniere observation de chaque atelier.
  static Map<String, ({List<CarnetItem> done, List<CarnetItem> ongoing})> byDomain(
      AppStateProvider provider, Child child, DateTimeRange range) {
    final end = range.end.add(const Duration(days: 1));
    final latest = <String, ActivityLog>{};
    for (final l in provider.activitiesForChild(child.id)) {
      if (l.timestamp.isBefore(range.start) || !l.timestamp.isBefore(end)) continue;
      final prev = latest[l.activityTypeId];
      if (prev == null || l.timestamp.isAfter(prev.timestamp)) latest[l.activityTypeId] = l;
    }
    final out = <String, ({List<CarnetItem> done, List<CarnetItem> ongoing})>{};
    for (final l in latest.values) {
      final a = provider.activityTypeById(l.activityTypeId);
      if (a == null) continue;
      final d = domainIdOf(a) ?? '';
      final slot = out.putIfAbsent(d, () => (done: <CarnetItem>[], ongoing: <CarnetItem>[]));
      (_done(provider, child.id, a, l) ? slot.done : slot.ongoing).add(CarnetItem(a, l));
    }
    for (final s in out.values) {
      s.done.sort((x, y) => y.log.timestamp.compareTo(x.log.timestamp));
      s.ongoing.sort((x, y) => x.atelier.name.toLowerCase().compareTo(y.atelier.name.toLowerCase()));
    }
    return out;
  }

  /// Niveau suggere pour un sous-domaine de la synthese, d'apres la derniere
  /// observation de chaque atelier qui le travaille (toute l'annee) ; null
  /// sans observation.
  static String? suggestedLevel(AppStateProvider provider, Child child, String subdomainId) {
    final title = EduscolData.subdomainById(subdomainId)?.title;
    if (title == null) return null;
    var done = 0, seen = 0;
    for (final a in provider.activityTypes) {
      if (!AtelierGrouping.subdomainTitlesOf(a).contains(title)) continue;
      final logs = provider.activitiesForChild(child.id).where((l) => l.activityTypeId == a.id).toList();
      if (logs.isEmpty) continue;
      logs.sort((x, y) => y.timestamp.compareTo(x.timestamp));
      seen++;
      if (_done(provider, child.id, a, logs.first)) done++;
    }
    if (seen == 0) return null;
    if (done > 0 && done * 2 >= seen) return CarnetEntry.levelOften;
    return done > 0 ? CarnetEntry.levelOnTheWay : CarnetEntry.levelNotYet;
  }

  // ─────────────── PDF ───────────────

  static PdfColor _color(String hex) {
    try {
      return PdfColor.fromInt(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return PdfColors.grey600;
    }
  }

  static pw.Widget _lines(int n) => pw.Column(children: [
        for (var i = 0; i < n; i++)
          pw.Container(
            height: 18,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
          ),
      ]);

  static pw.Widget _header(AppStateProvider provider, Child child, String title, String subtitle) {
    final s = provider.classSettings;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(pdfSafe(title), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
      pw.Text(pdfSafe(subtitle), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      pw.Text(pdfSafe('${child.firstname} ${child.lastname ?? ''}'.trim()),
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text(
          pdfSafe([
            if (child.group != null && child.group!.isNotEmpty) 'Section ${child.group}',
            s.name,
            if ((s.schoolName ?? '').isNotEmpty) s.schoolName!,
            s.schoolYear,
          ].join(' - ')),
          style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800)),
      pw.Divider(),
    ]);
  }

  static pw.Widget _itemCard(AppStateProvider provider, CarnetItem item) {
    final images = AtelierPdfService.imagesOf(provider, item.atelier);
    // Photos de l'observation d'abord (le travail de l'eleve), sinon celles
    // de l'atelier.
    final own = [
      for (final p in item.log.photoPaths)
        if (AtelierPdfService.imageAt(provider, p) case final img?) img,
    ];
    final shown = own.isNotEmpty ? own : images;
    return pw.Container(
      height: 168,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _color(item.atelier.colorHex), width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          height: 104,
          padding: const pw.EdgeInsets.all(3),
          color: shown.isEmpty ? _color(item.atelier.colorHex) : null,
          child: shown.isEmpty ? pw.SizedBox() : AtelierPdfService.photoMosaic(shown.take(4).toList()),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(pdfSafe(item.atelier.name),
                maxLines: 2, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd/MM/yyyy').format(item.log.timestamp),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            if (item.log.note != null && item.log.note!.trim().isNotEmpty)
              pw.Text(pdfSafe(item.log.note!.trim()),
                  maxLines: 2, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }

  static List<pw.Widget> _rows(List<pw.Widget> cards, int perRow) => [
        for (var i = 0; i < cards.length; i += perRow)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              for (var j = i; j < i + perRow; j++) ...[
                if (j > i) pw.SizedBox(width: 8),
                pw.Expanded(child: j < cards.length ? cards[j] : pw.SizedBox()),
              ],
            ]),
          ),
      ];

  /// Carnet d'une periode, pour un ou plusieurs eleves (chacun sur une page
  /// neuve).
  static Future<Uint8List> buildCarnetBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required String period,
    required DateTimeRange range,
    required PdfPageFormat format,
  }) async {
    final doc = pw.Document();
    final dates =
        '${DateFormat('dd/MM/yyyy').format(range.start)} au ${DateFormat('dd/MM/yyyy').format(range.end)}';
    for (final child in children) {
      final data = byDomain(provider, child, range);
      final entry = provider.carnetFor(child.id, period);
      final blocks = <pw.Widget>[];
      for (final d in EduscolData.domainsForCycle(1)) {
        final slot = data[d.id];
        final comment = entry.comments[d.id]?.trim() ?? '';
        if (slot == null && comment.isEmpty) continue;
        final rows = _rows([for (final it in slot?.done ?? const <CarnetItem>[]) _itemCard(provider, it)], 4);
        final title = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
          child: pw.Text(pdfSafe(d.title),
              style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _color(d.colorHex))),
        );
        // Le titre du domaine reste avec sa premiere ligne de reussites.
        blocks.add(pw.Inseparable(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            title,
            if (rows.isEmpty)
              pw.Text('Pas de réussite notée sur la période.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
            else
              rows.first,
          ]),
        ));
        blocks.addAll(rows.skip(1));
        if (slot != null && slot.ongoing.isNotEmpty) {
          blocks.add(pw.Text(pdfSafe('En cours : ${slot.ongoing.map((i) => i.atelier.name).join(', ')}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)));
        }
        if (comment.isNotEmpty) {
          blocks.add(pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(pdfSafe(comment), style: const pw.TextStyle(fontSize: 10)),
          ));
        }
      }
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          _header(provider, child, 'Carnet de suivi des apprentissages - Période ${period.substring(1)}',
              'Du $dates'),
          if (blocks.isEmpty)
            pw.Text('Aucune observation sur cette période.', style: const pw.TextStyle(fontSize: 11)),
          ...blocks,
          pw.SizedBox(height: 14),
          pw.Inseparable(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Mot de la famille', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              _lines(3),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Signature des parents :', style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(child: pw.Text('Signature de l\'enseignant(e) :', style: const pw.TextStyle(fontSize: 10))),
              ]),
              pw.SizedBox(height: 40),
            ]),
          ),
        ],
      ));
    }
    return doc.save();
  }

  /// Synthese des acquis de fin d'ecole maternelle : niveau par
  /// sous-domaine du programme, points forts, besoins, signatures.
  static Future<Uint8List> buildSyntheseBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
  }) async {
    final doc = pw.Document();
    const levels = [CarnetEntry.levelNotYet, CarnetEntry.levelOnTheWay, CarnetEntry.levelOften];
    pw.Widget cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(pdfSafe(text),
              textAlign: align, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : null)),
        );
    for (final child in children) {
      final entry = provider.carnetFor(child.id, CarnetEntry.synthese);
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(30),
        build: (_) => [
          _header(provider, child, 'Synthèse des acquis scolaires à la fin de l\'école maternelle',
              'D\'après le programme de l\'école maternelle (BO n° 41 du 31/10/2024 et BO n° 19 du 7/05/2026)'),
          for (final d in EduscolData.domainsForCycle(1))
            pw.Inseparable(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        cell(d.title, bold: true, align: pw.TextAlign.left),
                        for (final l in levels) cell(CarnetEntry.levelLabels[l]!, bold: true),
                      ],
                    ),
                    for (final s in EduscolData.subdomainsOf(d.id))
                      pw.TableRow(children: [
                        cell(s.title, align: pw.TextAlign.left),
                        for (final l in levels) cell(entry.levels[s.id] == l ? 'X' : '', bold: true),
                      ]),
                  ],
                ),
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Inseparable(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Points forts', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              entry.strengths.trim().isEmpty
                  ? _lines(3)
                  : pw.Text(pdfSafe(entry.strengths.trim()), style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text('Besoins à prendre en compte', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              entry.needs.trim().isEmpty
                  ? _lines(3)
                  : pw.Text(pdfSafe(entry.needs.trim()), style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('L\'enseignant(e) :', style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(child: pw.Text('Le directeur / la directrice :', style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(child: pw.Text('Les parents :', style: const pw.TextStyle(fontSize: 10))),
              ]),
              pw.SizedBox(height: 40),
              pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]),
          ),
        ],
      ));
    }
    return doc.save();
  }
}
