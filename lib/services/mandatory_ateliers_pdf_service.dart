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
import 'atelier_eligibility_service.dart';
import 'atelier_pdf_service.dart';
import 'atelier_status_resolver.dart';
import 'parcours_start.dart';

/// Reglages d'un plan de travail (ateliers ou parcours), choisis avant
/// l'export.
class WorkPlanOptions {
  /// Affiche le statut actuel sous le nom.
  final bool showStatus;

  /// Trois cases a cocher a la main sous chaque vignette.
  final bool showCheckboxes;

  /// Statuts a inclure (voir [WorkPlanOptions.keyOf]) ; null : tous.
  final Set<String>? statusKeys;

  /// Parcours a inclure (rapport des parcours) ; null : tous ceux que suit
  /// la section de l'eleve.
  final Set<String>? parcoursIds;

  /// Seulement ce que le planning prevoit pour l'eleve cette semaine.
  final bool onlyPlannedThisWeek;

  const WorkPlanOptions({
    this.showStatus = true,
    this.showCheckboxes = true,
    this.statusKeys,
    this.parcoursIds,
    this.onlyPlannedThisWeek = false,
  });

  /// Cle de filtre d'un statut : l'identifiant du niveau d'evaluation, ou
  /// [noLog] sans observation (« Jamais fait », ou observation sans niveau).
  static const noLog = 'none';
  static String keyOf(AtelierStatusSnapshot s) =>
      s.statusId == null || s.statusId == 'sans_statut' ? noLog : s.statusId!;
}

/// Plans de travail par eleve, en paysage et en vignettes de meme hauteur :
///  - [buildBytes] : les ateliers des espaces coches « plan de travail » pour
///    la section de l'eleve ;
///  - [buildParcoursBytes] : les etapes des parcours, rapport a part.
class MandatoryAteliersPdfService {
  static const _perRow = 4;
  static const _imageHeight = 118.0;

  // Plan de travail des ateliers : vignettes portrait compactes, 3 par ligne.
  static const _compactPerRow = 3;
  static const _compactGap = 8.0;
  static const _compactPhotoHeight = 50.0;
  static const _compactMaxObjectives = 2;

  static Future<Uint8List> buildBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) async {
    final doc = pw.Document();
    for (final child in children) {
      final planned = options.onlyPlannedThisWeek ? provider.plannedAteliersForWeek(child, DateTime.now()) : null;
      final ateliers = provider.activityTypes
          .where((a) => !a.inProgression && a.isObligatoryForGroup(child.group))
          .where((a) => planned == null || planned.contains(a.id))
          .toList();
      // Pas de titre d'espace : les ateliers se suivent, regroupes par domaine
      // (ordre du programme Eduscol) pour tenir un maximum de vignettes par page.
      final ordered = [...ateliers]..sort((a, b) {
          final byDomain = _domainRank(a).compareTo(_domainRank(b));
          if (byDomain != 0) return byDomain;
          final byLabel = a.domaine.compareTo(b.domaine);
          return byLabel != 0 ? byLabel : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      final vignettes = <pw.Widget>[
        for (final a in ordered)
          if (_compactVignette(provider: provider, child: child, atelier: a, options: options) case final v?) v,
      ];
      final groups = <(String, List<pw.Widget>)>[
        if (vignettes.isNotEmpty) ('', vignettes),
      ];

      _addChildPages(
        doc,
        provider,
        format,
        child,
        title: 'Plan de travail',
        groups: groups,
        portrait: true,
        perRow: _compactPerRow,
        rowGap: _compactGap,
        showGroupTitles: false,
        empty: ateliers.isEmpty
            ? 'Aucun atelier dans le plan de travail de cette section.'
            : 'Aucun atelier ne correspond aux statuts choisis.',
      );
    }
    return doc.save();
  }

  static Future<Uint8List> buildParcoursBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) async {
    final doc = pw.Document();
    for (final child in children) {
      final parcours = provider.progressions
          .where((p) => options.parcoursIds == null
              ? p.concernsGroup(child.group)
              : options.parcoursIds!.contains(p.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final groups = <(String, List<pw.Widget>)>[];
      for (final p in parcours) {
        final steps = provider.ateliersInProgressionOrdered(p.id);
        // Un eleve qui demarre en cours de parcours ne recoit que ses etapes.
        final start = ParcoursStart.indexFor(child, p.id, steps);
        final planned = options.onlyPlannedThisWeek ? provider.plannedAteliersForWeek(child, DateTime.now()) : null;
        final vignettes = <pw.Widget>[
          for (final (i, s) in steps.indexed)
            if (i >= start)
            if (planned == null || planned.contains(s.id))
            if (_vignette(
              provider: provider,
              child: child,
              atelier: s,
              options: options,
              stepLabel: 'Étape ${i + 1}',
              // Etape validee des qu'elle atteint le seuil du parcours.
              done: AtelierEligibilityService.meetsThreshold(provider, child.id, s.id, p.minStatusId),
            )
                case final v?)
              v,
        ];
        if (vignettes.isNotEmpty) groups.add((p.name, vignettes));
      }

      _addChildPages(
        doc,
        provider,
        format,
        child,
        title: 'Parcours',
        groups: groups,
        empty: parcours.isEmpty
            ? 'Aucun parcours pour cet élève.'
            : 'Aucune étape ne correspond aux statuts choisis.',
      );
    }
    return doc.save();
  }

  /// Pages d'un eleve : en-tete, puis chaque groupe (espace ou parcours).
  /// Le titre d'un groupe et sa premiere ligne de vignettes forment un bloc
  /// insecable : un titre ne reste jamais seul en bas de page.
  static void _addChildPages(
    pw.Document doc,
    AppStateProvider provider,
    PdfPageFormat format,
    Child child, {
    required String title,
    required List<(String, List<pw.Widget>)> groups,
    required String empty,
    bool portrait = false,
    int perRow = _perRow,
    double rowGap = 10,
    bool showGroupTitles = true,
  }) {
    final settings = provider.classSettings;
    doc.addPage(pw.MultiPage(
      pageFormat: portrait ? format.portrait : format.landscape,
      margin: pw.EdgeInsets.all(portrait ? 24 : 28),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(pdfSafe('$title - ${child.firstname} ${child.lastname ?? ''}'.trim()),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    [
                      if (child.group != null && child.group!.isNotEmpty) 'Section ${child.group}',
                      settings.name,
                      settings.schoolYear,
                    ].map(pdfSafe).join(' - '),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
      build: (context) {
        if (groups.isEmpty) {
          return [pw.Text(empty, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))];
        }
        final out = <pw.Widget>[];
        for (final (name, vignettes) in groups) {
          final rows = _rows(vignettes, perRow: perRow, gap: rowGap);
          if (!showGroupTitles) {
            out.addAll(rows);
            continue;
          }
          // Bloc insecable : une Column (et un Container, qui en herite) peut
          // etre coupee entre deux pages par MultiPage.
          out.add(pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
                  child: pw.Text(pdfSafe(name), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ),
                rows.first,
              ],
            ),
          ));
          out.addAll(rows.skip(1));
        }
        return out;
      },
    ));
  }

  /// Lignes de [perRow] vignettes, chacune insecable.
  static List<pw.Widget> _rows(List<pw.Widget> vignettes, {int perRow = _perRow, double gap = 10}) => [
        for (var i = 0; i < vignettes.length; i += perRow)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: gap),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + perRow; j++) ...[
                  if (j > i) pw.SizedBox(width: gap),
                  pw.Expanded(child: j < vignettes.length ? vignettes[j] : pw.SizedBox()),
                ],
              ],
            ),
          ),
      ];

  /// Vrai si le statut actuel de l'atelier pour cet eleve fait partie des
  /// statuts retenus.
  static bool includes(AppStateProvider provider, Child child, ActivityType atelier, WorkPlanOptions options) {
    if (options.statusKeys == null) return true;
    final snapshot = AtelierStatusResolver.resolve(provider: provider, childId: child.id, activityTypeId: atelier.id);
    return options.statusKeys!.contains(WorkPlanOptions.keyOf(snapshot));
  }

  /// Hauteur commune de toutes les vignettes d'un export : elle ne depend que
  /// des reglages, jamais du contenu (nombre de photos, longueur du nom).
  static double _height(WorkPlanOptions o, {required bool step}) =>
      _imageHeight + 8 + (step ? 11 : 0) + 28 + (o.showStatus ? 13 : 0) + (o.showCheckboxes ? 30 : 0) + 10;

  /// Vignette d'un atelier (ou d'une etape) pour un eleve, ou null si son
  /// statut n'est pas retenu : toutes les photos, le nom, le statut et trois
  /// cases a cocher selon les reglages ; bordure verte une fois acquis.
  static pw.Widget? _vignette({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
    required WorkPlanOptions options,
    String? stepLabel,
    bool? done,
  }) {
    if (!includes(provider, child, atelier, options)) return null;
    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final acquis = done ?? snapshot.statusId == 'acquis';
    final statusColor = _color(snapshot.colorHex);
    final atelierColor = _color(atelier.colorHex);
    final images = AtelierPdfService.imagesOf(provider, atelier);
    final initial = atelier.name.trim().isEmpty ? '?' : atelier.name.trim()[0].toUpperCase();

    return pw.Container(
      height: _height(options, step: stepLabel != null),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: acquis ? PdfColors.green700 : atelierColor, width: acquis ? 2 : 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Toutes les photos, entieres (ou pastille a l'initiale).
          pw.Container(
            height: _imageHeight,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: images.isEmpty ? atelierColor : null,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            alignment: pw.Alignment.center,
            child: images.isNotEmpty
                ? AtelierPdfService.photoMosaic(images)
                : pw.Text(pdfSafe(initial),
                    style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (stepLabel != null)
                  pw.SizedBox(
                    height: 11,
                    child: pw.Text(pdfSafe(stepLabel),
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: atelierColor)),
                  ),
                // Nom sur deux lignes au plus, place reservee meme s'il est court.
                pw.SizedBox(
                  height: 28,
                  child: pw.Text(pdfSafe(atelier.name),
                      maxLines: 2, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
                if (options.showStatus)
                  pw.SizedBox(
                    height: 13,
                    child: pw.Text(pdfSafe(acquis ? '${snapshot.label} - fait !' : snapshot.label),
                        maxLines: 1,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: statusColor)),
                  ),
                if (options.showCheckboxes)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    // Trois passages a cocher a la main, sur la feuille.
                    child: pw.Row(
                      children: [
                        for (var k = 0; k < 3; k++)
                          pw.Container(
                            width: 22,
                            height: 22,
                            margin: const pw.EdgeInsets.only(right: 8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hauteur commune des vignettes compactes : elle ne depend que des
  /// reglages, jamais du contenu, pour que la grille reste alignee.
  static double _compactHeight(WorkPlanOptions o) =>
      150 + (o.showStatus || o.showCheckboxes ? 22 : 0);

  /// Rang du domaine dans le programme Eduscol ; les domaines saisis librement
  /// viennent ensuite.
  static int _domainRank(ActivityType atelier) {
    final index = EduscolData.domains.indexWhere(
      (d) => d.id == atelier.domaineId || d.title == atelier.domaine,
    );
    return index == -1 ? EduscolData.domains.length : index;
  }

  /// Niveaux (PS / MS / GS) des objectifs Eduscol de l'atelier. Les objectifs
  /// saisis librement n'ont pas de niveau.
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

  /// Vignette portrait compacte d'un atelier : nom, photos, domaine, sous-domaine
  /// (ou niveau) et objectifs, puis (selon les reglages) trois cases a cocher a la main et le
  /// statut. Bordure verte une fois acquis. Null si le statut n'est pas retenu.
  static pw.Widget? _compactVignette({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
    required WorkPlanOptions options,
  }) {
    if (!includes(provider, child, atelier, options)) return null;
    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final acquis = snapshot.statusId == 'acquis';
    final statusColor = _color(snapshot.colorHex);
    final atelierColor = _color(atelier.colorHex);
    final images = AtelierPdfService.imagesOf(provider, atelier);
    final initial = atelier.name.trim().isEmpty ? '?' : atelier.name.trim()[0].toUpperCase();
    // Le sous-domaine enregistre sur l'atelier ; a defaut, le niveau (PS / MS /
    // GS) des objectifs du programme.
    final sousDomaine = EduscolData.subdomainById(atelier.sousDomaineId)?.title;
    final niveau = _levelsOf(atelier);
    final shown = atelier.objectifs.take(_compactMaxObjectives).toList();
    final hidden = atelier.objectifs.length - shown.length;

    return pw.Container(
      height: _compactHeight(options),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: acquis ? PdfColors.green700 : atelierColor, width: acquis ? 2 : 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.ClipRect(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: pw.SizedBox(
                height: 22,
                child: pw.Text(pdfSafe(atelier.name),
                    maxLines: 2, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            // Toutes les photos, entieres (ou pastille a l'initiale).
            pw.Container(
              height: _compactPhotoHeight,
              margin: const pw.EdgeInsets.fromLTRB(6, 3, 6, 0),
              decoration: pw.BoxDecoration(
                color: images.isEmpty ? atelierColor : null,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              alignment: pw.Alignment.center,
              child: images.isNotEmpty
                  ? AtelierPdfService.photoMosaic(images, gap: 2)
                  : pw.Text(pdfSafe(initial),
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 3, 6, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (atelier.domaine.isNotEmpty)
                    pw.Text(pdfSafe(atelier.domaine),
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  if (sousDomaine != null)
                    pw.Text(pdfSafe(sousDomaine),
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic))
                  else if (niveau != null)
                    pw.Text('Niveau : ${pdfSafe(niveau)}',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                  pw.SizedBox(height: 1.5),
                  for (final o in shown)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 0.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('- ', style: const pw.TextStyle(fontSize: 6.5)),
                          pw.Expanded(
                            child: pw.Text(pdfSafe(o), maxLines: 2, style: const pw.TextStyle(fontSize: 6.5)),
                          ),
                        ],
                      ),
                    ),
                  if (hidden > 0)
                    pw.Text('+ $hidden autre${hidden > 1 ? 's' : ''}',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.Spacer(),
            if (options.showStatus || options.showCheckboxes)
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 0, 6, 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Trois passages a cocher a la main, sur la feuille.
                    if (options.showCheckboxes)
                      for (var k = 0; k < 3; k++)
                        pw.Container(
                          width: 14,
                          height: 14,
                          margin: const pw.EdgeInsets.only(right: 4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey700, width: 1.2),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                        ),
                    pw.Spacer(),
                    if (options.showStatus)
                      pw.Text(pdfSafe(acquis ? '${snapshot.label} - fait !' : snapshot.label),
                          maxLines: 1,
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: statusColor)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static PdfColor _color(String hex) {
    try {
      return PdfColor.fromInt(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return PdfColors.grey600;
    }
  }

  static String _fileLabel(List<Child> children) {
    final label = children.length == 1 ? children.first.firstname : '${children.length}_eleves';
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim().replaceAll(' ', '_');
    return safe.isEmpty ? 'eleves' : safe;
  }

  /// Apercu imprimable / partageable du plan de travail (ateliers).
  static void exportForChildren({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) {
    openPdfViewer(
      context,
      title: 'Plan de travail',
      fileName: 'Plan_de_travail_${_fileLabel(children)}.pdf',
      build: (format) => buildBytes(provider: provider, children: children, format: format, options: options),
      shareSubject: 'Plan de travail - A petits pas',
      shareBody: 'Veuillez trouver ci-joint le plan de travail.',
    );
  }

  /// Apercu imprimable / partageable du plan des parcours.
  static void exportParcoursForChildren({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
    WorkPlanOptions options = const WorkPlanOptions(),
  }) {
    openPdfViewer(
      context,
      title: 'Parcours des élèves',
      fileName: 'Parcours_${_fileLabel(children)}.pdf',
      build: (format) =>
          buildParcoursBytes(provider: provider, children: children, format: format, options: options),
      shareSubject: 'Parcours - A petits pas',
      shareBody: 'Veuillez trouver ci-joint les parcours.',
    );
  }
}
