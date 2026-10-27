import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/eduscol_data.dart';
import '../data/sons_data.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/progression.dart';
import '../models/referential.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';
import 'atelier_grouping.dart';

/// Rapport d'activites PDF d'un ou plusieurs eleves, lance depuis l'ecran
/// Rapports et reglable (periode, analyse des sons, referentiels,
/// regroupement des activites par domaine / sous-domaine et parcours).
class ChildActivityReportService {
  static PdfColor _sonPdfColor(SonStatut statut) => switch (statut) {
        SonStatut.nonAcquis => const PdfColor.fromInt(0xFFD32F2F),
        SonStatut.enCours => const PdfColor.fromInt(0xFFF9A825),
        SonStatut.acquis => const PdfColor.fromInt(0xFF388E3C),
      };

  /// Pastille coloree portant le son, lisible meme imprimee en niveaux de gris
  /// grace au libelle de la legende qui l'accompagne.
  static pw.Widget _sonChip(String son, SonStatut statut) {
    final color = _sonPdfColor(statut);
    return pw.Container(
      width: 26,
      height: 26,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(13)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        son,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// Item d'un referentiel : libelle libre, souvent plus long qu'un son
  /// (« Ceinture blanche ») : pastille allongee plutot que ronde.
  static pw.Widget _itemChip(String label, SonStatut statut) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _sonPdfColor(statut),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Text(pdfSafe(label),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      );

  static pw.Widget _sonLegendeItem(SonStatut statut) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 9,
          height: 9,
          decoration: pw.BoxDecoration(
            color: _sonPdfColor(statut),
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(statut.libelle, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
      ],
    );
  }

  static List<pw.Widget> _buildSonsSection(Child child, AppStateProvider provider) {
    final tous = SonsData.tous;
    final acquis = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.acquis).length;
    final enCours = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.enCours).length;

    return [
      pw.Text(pdfSafe('Analyse des sons — état actuel'),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text(
        pdfSafe('Langage · conscience phonémique & signes graphiques — '
            '$acquis acquis, $enCours en cours sur ${tous.length} sons.'),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          _sonLegendeItem(SonStatut.acquis),
          pw.SizedBox(width: 12),
          _sonLegendeItem(SonStatut.enCours),
          pw.SizedBox(width: 12),
          _sonLegendeItem(SonStatut.nonAcquis),
        ],
      ),
      pw.SizedBox(height: 8),
      ...SonsData.groupes.map((groupe) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 84,
                  child: pw.Text(groupe.titre,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: groupe.sons
                        .map((son) => _sonChip(son, provider.sonStatut(child.id, son)))
                        .toList(),
                  ),
                ),
              ],
            ),
          )),
      pw.Divider(),
      pw.SizedBox(height: 8),
    ];
  }

  /// Suivi d'un referentiel personnalise : meme presentation que l'analyse
  /// des sons (etat actuel de chaque item, groupe par groupe).
  static List<pw.Widget> _buildReferentialSection(Child child, AppStateProvider provider, Referential r) {
    final items = r.allItems;
    final acquis = items.where((i) => provider.referentialItemStatut(r.id, child.id, i.id) == SonStatut.acquis).length;
    final enCours =
        items.where((i) => provider.referentialItemStatut(r.id, child.id, i.id) == SonStatut.enCours).length;
    return [
      pw.Text(pdfSafe('${r.name} - état actuel'), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text('$acquis acquis, $enCours en cours sur ${items.length}.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        _sonLegendeItem(SonStatut.acquis),
        pw.SizedBox(width: 12),
        _sonLegendeItem(SonStatut.enCours),
        pw.SizedBox(width: 12),
        _sonLegendeItem(SonStatut.nonAcquis),
      ]),
      pw.SizedBox(height: 8),
      for (final g in r.groups)
        if (g.items.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 84,
                  child: pw.Text(pdfSafe(g.title), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final i in g.items)
                        _itemChip(i.label, provider.referentialItemStatut(r.id, child.id, i.id)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      pw.Divider(),
      pw.SizedBox(height: 8),
    ];
  }

  static Future<Uint8List> generateChildReportBytes({
    required Child child,
    required AppStateProvider provider,
    required PdfPageFormat format,
    ChildReportOptions options = const ChildReportOptions(),
  }) =>
      generateReportBytes(provider: provider, children: [child], format: format, options: options);

  /// Rapport d'un ou plusieurs eleves : une page de garde s'il y en a
  /// plusieurs, puis chaque eleve sur une page neuve (pour imprimer et
  /// distribuer les rapports separement).
  static Future<Uint8List> generateReportBytes({
    required AppStateProvider provider,
    required List<Child> children,
    required PdfPageFormat format,
    ChildReportOptions options = const ChildReportOptions(),
  }) async {
    final settings = provider.classSettings;
    final sorted = children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    final doc = pw.Document();

    if (sorted.length > 1) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Rapport des élèves', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text(pdfSafe(settings.name), style: const pw.TextStyle(fontSize: 16)),
                pw.Text(pdfSafe(settings.teacher), style: const pw.TextStyle(fontSize: 13)),
                pw.Text(pdfSafe(settings.schoolYear), style: const pw.TextStyle(fontSize: 13)),
                pw.SizedBox(height: 18),
                pw.Text('Période : ${pdfSafe(options.periodLabel)}',
                    style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                pw.Text('${sorted.length} élève(s)', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 24),
                pw.Text('Édité le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
        ),
      );
    }

    // Avec plusieurs eleves, le nombre de photos par eleve est borne : sans
    // limite, toutes les photos de la classe seraient chargees en memoire a la
    // fois avant le rendu, ce qui peut faire planter l'appli.
    final maxPhotos = sorted.length > 1 ? 4 : null;
    for (final child in sorted) {
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        build: (context) => buildChildReport(
          child: child,
          provider: provider,
          options: options,
          maxPhotosPerChild: maxPhotos,
        ),
      ));
    }
    return doc.save();
  }

  /// Rapport complet d'un eleve, sous forme de contenu de page.
  static List<pw.Widget> buildChildReport({
    required Child child,
    required AppStateProvider provider,
    ChildReportOptions options = const ChildReportOptions(),
    // Nombre de photos reellement chargees pour cet eleve (null : illimite).
    int? maxPhotosPerChild,
  }) {
    var childLogs = provider.activitiesForChild(child.id).toList();
    if (options.from != null) {
      childLogs =
          childLogs.where((l) => l.timestamp.isAfter(options.from!.subtract(const Duration(seconds: 1)))).toList();
    }
    if (options.to != null) {
      childLogs = childLogs.where((l) => l.timestamp.isBefore(options.to!)).toList();
    }
    childLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (options.onlyLatestPerAtelier) {
      // Deja trie du plus recent au plus ancien : la premiere occurrence
      // rencontree par atelier est la plus recente.
      final seen = <String>{};
      childLogs = childLogs.where((l) => seen.add(l.activityTypeId)).toList();
    }

    pw.MemoryImage? profileImage;
    final profilePath = provider.getAbsolutePath(child.imagePath);
    if (profilePath != null && File(profilePath).existsSync()) {
      profileImage = pw.MemoryImage(File(profilePath).readAsBytesSync());
    }

    final budget = _PhotoBudget(maxPhotosPerChild);
    final referentials = [
      for (final r in provider.referentials)
        if (options.referentialIds == null || options.referentialIds!.contains(r.id)) r,
    ];

    return [
      pw.Header(
        level: 0,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Rapport d\'activités - A petits pas',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text('Période : ${pdfSafe(options.periodLabel)}',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
      if (options.onlyLatestPerAtelier)
        pw.Text('Une seule occurrence par atelier (la plus récente)',
            style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
      pw.SizedBox(height: 14),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${pdfSafe(child.firstname)} ${pdfSafe(child.lastname ?? "")}',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              if (child.group != null && child.group!.isNotEmpty)
                pw.Text('Groupe/Section : ${pdfSafe(child.group!)}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
              if (child.parentEmails.isNotEmpty)
                pw.Text('Email de contact : ${pdfSafe(child.parentEmails.join(' ; '))}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
              if (child.notes != null && child.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Notes : ${pdfSafe(child.notes!)}',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              ],
            ],
          ),
          if (profileImage != null)
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
      ),
      pw.SizedBox(height: 16),

      // Etats courants (pas un historique) : en tete, quelle que soit la
      // periode demandee.
      if (options.includeSons) ..._buildSonsSection(child, provider),
      for (final r in referentials) ..._buildReferentialSection(child, provider, r),

      pw.Text('Historique des activités (${childLogs.length}) :',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Divider(),
      pw.SizedBox(height: 8),
      if (childLogs.isEmpty)
        pw.Text('Aucune activité enregistrée pour cette période.', style: const pw.TextStyle(fontSize: 11))
      else if (!options.groupActivities)
        for (final log in childLogs) _logCard(log, provider, budget)
      else
        ..._groupedLogs(childLogs, provider, budget),
    ];
  }

  /// Activites regroupees : ateliers par domaine puis sous-domaine, etapes
  /// par parcours (dans l'ordre du fil). Chaque titre reste sur la meme page
  /// que la premiere observation qui le suit.
  static List<pw.Widget> _groupedLogs(List<ActivityLog> logs, AppStateProvider provider, _PhotoBudget budget) {
    final out = <pw.Widget>[];
    void section(List<pw.Widget> headings, List<ActivityLog> group) {
      if (group.isEmpty) return;
      out.add(pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [...headings, _logCard(group.first, provider, budget)],
        ),
      ));
      for (final log in group.skip(1)) {
        out.add(_logCard(log, provider, budget));
      }
    }

    pw.Widget heading(String text, {required int level}) => pw.Padding(
          padding: pw.EdgeInsets.only(top: level == 0 ? 10 : 4, bottom: 6),
          child: pw.Text(pdfSafe(text),
              style: pw.TextStyle(
                fontSize: level == 0 ? 14 : 11.5,
                fontWeight: pw.FontWeight.bold,
                color: level == 0 ? PdfColors.indigo900 : PdfColors.indigo700,
              )),
        );

    final atelierLogs = <ActivityLog>[];
    final stepLogs = <String, List<ActivityLog>>{};
    for (final log in logs) {
      final a = provider.activityTypeById(log.activityTypeId);
      if (a != null && a.inProgression) {
        (stepLogs[a.progressionId!] ??= []).add(log);
      } else {
        atelierLogs.add(log);
      }
    }

    // Ateliers : un seul sous-domaine par atelier (le choisi, sinon le premier
    // deduit), pour qu'une observation n'apparaisse qu'une fois.
    final byId = {for (final l in atelierLogs) l.id: l};
    final ateliers = {
      for (final l in atelierLogs)
        l.activityTypeId: provider.activityTypeById(l.activityTypeId) ??
            ActivityType(id: l.activityTypeId, name: 'Atelier inconnu', spaceId: '', colorHex: '#718096'),
    };
    for (final d in AtelierGrouping.byDomain(ateliers.values)) {
      final bySub = <String, List<ActivityLog>>{};
      for (final a in d.value) {
        final subs = AtelierGrouping.subdomainTitlesOf(a);
        final sub = subs.isEmpty ? AtelierGrouping.otherSubdomain : subs.first;
        bySub.putIfAbsent(sub, () => []).addAll(byId.values.where((l) => l.activityTypeId == a.id));
      }
      final subOrder = AtelierGrouping.bySubdomain(d.value).map((e) => e.key).toList();
      final keys = bySub.keys.toList()..sort((x, y) => subOrder.indexOf(x).compareTo(subOrder.indexOf(y)));
      var first = true;
      for (final sub in keys) {
        final group = bySub[sub]!..sort((x, y) => y.timestamp.compareTo(x.timestamp));
        final onlyOther = keys.length == 1 && sub == AtelierGrouping.otherSubdomain;
        section([
          if (first) heading(d.key, level: 0),
          if (!onlyOther) heading(sub, level: 1),
        ], group);
        first = false;
      }
    }

    // Parcours : par etape dans l'ordre du fil, puis du plus recent au plus ancien.
    final parcours = stepLogs.keys.map(provider.progressionById).whereType<Progression>().toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final p in parcours) {
      final position = {for (final s in provider.ateliersInProgressionOrdered(p.id)) s.id: s.position};
      final group = stepLogs[p.id]!
        ..sort((x, y) {
          final c = (position[x.activityTypeId] ?? 0).compareTo(position[y.activityTypeId] ?? 0);
          return c != 0 ? c : y.timestamp.compareTo(x.timestamp);
        });
      section([heading('Parcours · ${p.name}', level: 0)], group);
    }
    return out;
  }

  /// Carte d'une observation : atelier, date, domaine, objectifs, statut,
  /// note et photos legendees.
  static pw.Widget _logCard(ActivityLog log, AppStateProvider provider, _PhotoBudget budget) {
    final actType = provider.activityTypeById(log.activityTypeId) ??
        ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: '#718096');
    final space = provider.placeOf(actType) ?? Space(id: '', name: '', colorHex: '');
    final stepIndex = actType.inProgression
        ? provider.ateliersInProgressionOrdered(actType.progressionId!).indexWhere((s) => s.id == actType.id)
        : -1;

    final List<({pw.MemoryImage image, String? caption})> activityImages = [];
    var skippedPhotos = 0;
    for (final path in log.photoPaths) {
      final resolvedPath = provider.getAbsolutePath(path);
      if (resolvedPath == null || !File(resolvedPath).existsSync()) continue;
      if (!budget.take()) {
        skippedPhotos++;
        continue;
      }
      activityImages.add((image: pw.MemoryImage(File(resolvedPath).readAsBytesSync()), caption: log.captionFor(path)));
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                    stepIndex >= 0
                        ? 'Étape ${stepIndex + 1} : ${pdfSafe(actType.name)}'
                        : 'Atelier : ${pdfSafe(actType.name)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
              pw.Text(
                  '${actType.inProgression ? 'Parcours' : 'Espace'} : '
                  '${pdfSafe(space.name.isEmpty ? "Non défini" : space.name)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          if (actType.domaine.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
                'Domaine : ${pdfSafe(actType.domaine)}'
                '${EduscolData.subdomainById(actType.sousDomaineId) == null ? '' : ' > ${pdfSafe(EduscolData.subdomainById(actType.sousDomaineId)!.title)}'}',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          ],
          if (actType.objectifs.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text('Objectifs visés :',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            ...actType.objectifs.map((obj) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 1),
                  child: pw.Text('- ${pdfSafe(obj)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                )),
          ],
          if (provider.statusLabel(log) != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Statut : ${pdfSafe(provider.statusLabel(log)!)}',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          ],
          if (log.note != null && log.note!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Observation : ${pdfSafe(log.note!)}',
                style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey900)),
          ],
          if (activityImages.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: activityImages.map((photo) {
                return pw.SizedBox(
                  width: 92,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: 92,
                        height: 70,
                        decoration: const pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                          color: PdfColors.grey100,
                        ),
                        child: pw.Image(photo.image, fit: pw.BoxFit.contain), // photo entiere
                      ),
                      if (photo.caption != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(pdfSafe(photo.caption!),
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (skippedPhotos > 0) ...[
            pw.SizedBox(height: 4),
            pw.Text('+$skippedPhotos photo${skippedPhotos > 1 ? "s" : ""}, voir le rapport individuel',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
          ],
        ],
      ),
    );
  }
}

/// Reglages du rapport des eleves.
class ChildReportOptions {
  /// Periode [from, to[ ; null : toute la periode.
  final DateTime? from;
  final DateTime? to;

  /// Une seule observation par atelier, la plus recente.
  final bool onlyLatestPerAtelier;

  /// Analyse des sons en tete du rapport.
  final bool includeSons;

  /// Referentiels personnalises a inclure ; null : tous.
  final Set<String>? referentialIds;

  /// Activites par domaine / sous-domaine et par parcours ; sinon dans
  /// l'ordre chronologique.
  final bool groupActivities;

  const ChildReportOptions({
    this.from,
    this.to,
    this.onlyLatestPerAtelier = false,
    this.includeSons = true,
    this.referentialIds,
    this.groupActivities = true,
  });

  String get periodLabel => (from != null && to != null)
      ? '${DateFormat('dd/MM/yyyy').format(from!)} - ${DateFormat('dd/MM/yyyy').format(to!.subtract(const Duration(days: 1)))}'
      : 'Toute la période';
}

/// Nombre de photos encore autorisees pour un eleve (null : illimite).
class _PhotoBudget {
  _PhotoBudget(this._left);
  int? _left;

  bool take() {
    if (_left == null) return true;
    if (_left! <= 0) return false;
    _left = _left! - 1;
    return true;
  }
}
