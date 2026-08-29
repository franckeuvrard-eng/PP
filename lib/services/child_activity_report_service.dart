import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/sons_data.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/pdf_text.dart';

/// Rapport d'activites PDF d'un eleve (et rapport de classe, qui l'assemble
/// pour chaque eleve) : partage entre le declencheur par eleve
/// (children_manager_screen.dart) et le rapport de classe centralise dans
/// l'ecran Rapports, pour ne pas dupliquer la mise en page.
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

  static Future<Uint8List> generateChildReportBytes({
    required Child child,
    required AppStateProvider provider,
    required PdfPageFormat format,
    DateTime? from,
    DateTime? to,
    bool onlyLatestPerAtelier = false,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      build: (context) => buildChildReport(
        child: child,
        provider: provider,
        from: from,
        to: to,
        onlyLatestPerAtelier: onlyLatestPerAtelier,
      ),
    ));
    return doc.save();
  }

  /// Rapport complet d'un eleve, sous forme de contenu de page.
  ///
  /// Isole du document pour pouvoir etre repris tel quel dans l'export de
  /// toute la classe, ou chaque eleve occupe sa propre section.
  static List<pw.Widget> buildChildReport({
    required Child child,
    required AppStateProvider provider,
    DateTime? from,
    DateTime? to,
    bool onlyLatestPerAtelier = false,
    // Borne le nombre de photos reellement chargees/embarquees pour cet
    // eleve (null = illimite). Le rapport de classe entiere l'utilise pour
    // ne pas charger en memoire les photos de toute la classe a la fois ;
    // le rapport individuel n'a pas cette limite.
    int? maxPhotosPerChild,
  }) {
    // Filter logs by period
    var childLogs = provider.activitiesForChild(child.id).toList();
    if (from != null) {
      childLogs = childLogs.where((l) => l.timestamp.isAfter(from.subtract(const Duration(seconds: 1)))).toList();
    }
    if (to != null) {
      childLogs = childLogs.where((l) => l.timestamp.isBefore(to)).toList();
    }
    childLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (onlyLatestPerAtelier) {
      // childLogs est deja trie du plus recent au plus ancien : ne garder
      // que la premiere occurrence rencontree par atelier suffit a isoler
      // la plus recente, sans re-trier par atelier.
      final seen = <String>{};
      childLogs = childLogs.where((l) => seen.add(l.activityTypeId)).toList();
    }

    // Profile photo bytes
    pw.MemoryImage? profileImage;
    final profilePath = provider.getAbsolutePath(child.imagePath);
    if (profilePath != null && File(profilePath).existsSync()) {
      profileImage = pw.MemoryImage(File(profilePath).readAsBytesSync());
    }

    final periodLabel = (from != null && to != null)
        ? '${DateFormat('dd/MM/yyyy').format(from)} → ${DateFormat('dd/MM/yyyy').format(to.subtract(const Duration(days: 1)))}'
        : 'Toute la période';

    var remainingPhotoBudget = maxPhotosPerChild;

    return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rapport d\'activités - A petits pas',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Période : ${pdfSafe(periodLabel)}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
            if (onlyLatestPerAtelier)
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
                    pw.Text(
                        '${pdfSafe(child.firstname)} ${pdfSafe(child.lastname ?? "")}',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    if (child.group != null && child.group!.isNotEmpty)
                      pw.Text('Groupe/Section : ${pdfSafe(child.group!)}',
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.email != null && child.email!.isNotEmpty)
                      pw.Text('Email de contact : ${pdfSafe(child.email ?? "")}',
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

            // L'analyse des sons est un etat courant, pas un historique :
            // elle figure en tete quelle que soit la periode demandee.
            ..._buildSonsSection(child, provider),

            pw.Text('Historique des activités (${childLogs.length}) :',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 8),

            if (childLogs.isEmpty)
              pw.Text('Aucune activité enregistrée pour cette période.', style: const pw.TextStyle(fontSize: 11))
            else
              ...childLogs.map((log) {
                final actType = provider.activityTypeById(log.activityTypeId) ??
                    ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: '#718096');

                final space = provider.spaceById(actType.spaceId) ??
                    Space(id: '', name: '', colorHex: '');

                // Chaque photo est accompagnee de sa legende quand elle en a une.
                final List<({pw.MemoryImage image, String? caption})> activityImages = [];
                var skippedPhotos = 0;
                for (final path in log.photoPaths) {
                  final resolvedPath = provider.getAbsolutePath(path);
                  if (resolvedPath == null || !File(resolvedPath).existsSync()) continue;
                  if (remainingPhotoBudget != null && remainingPhotoBudget! <= 0) {
                    skippedPhotos++;
                    continue;
                  }
                  activityImages.add((
                    image: pw.MemoryImage(File(resolvedPath).readAsBytesSync()),
                    caption: log.captionFor(path),
                  ));
                  if (remainingPhotoBudget != null) remainingPhotoBudget = remainingPhotoBudget! - 1;
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
                          pw.Text('Atelier : ${pdfSafe(actType.name)}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text('Espace : ${pdfSafe(space.name.isEmpty ? "Non défini" : space.name)}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Date : ${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      if (actType.domaine.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text('Domaine : ${pdfSafe(actType.domaine)}',
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
                            style: pw.TextStyle(
                                fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
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
                                    child: pw.Image(photo.image, fit: pw.BoxFit.cover),
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
                        pw.Text(
                          '+$skippedPhotos photo${skippedPhotos > 1 ? "s" : ""}, voir la fiche individuelle',
                          style: pw.TextStyle(
                              fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                        ),
                      ],
                    ],
                  ),
                );
              }),
    ];
  }

  /// Rapport de toute la classe : une page de garde puis chaque eleve.
  static Future<Uint8List> generateClassReportBytes({
    required AppStateProvider provider,
    required PdfPageFormat format,
    DateTime? from,
    DateTime? to,
    bool onlyLatestPerAtelier = false,
  }) async {
    final settings = provider.classSettings;
    final children = provider.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));

    final periodLabel = (from != null && to != null)
        ? '${DateFormat('dd/MM/yyyy').format(from)} - ${DateFormat('dd/MM/yyyy').format(to.subtract(const Duration(days: 1)))}'
        : 'Toute la période';

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Rapport de classe',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text(pdfSafe(settings.name), style: const pw.TextStyle(fontSize: 16)),
              pw.Text(pdfSafe(settings.teacher), style: const pw.TextStyle(fontSize: 13)),
              pw.Text(pdfSafe(settings.schoolYear), style: const pw.TextStyle(fontSize: 13)),
              pw.SizedBox(height: 18),
              pw.Text('Période : ${pdfSafe(periodLabel)}',
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              pw.Text('${children.length} élève(s)', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 24),
              pw.Text('Édité le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
      ),
    );

    // Un MultiPage par eleve : chacun demarre ainsi sur une page neuve, ce qui
    // permet d'imprimer et de distribuer les rapports separement.
    //
    // Le budget de photos par eleve est borne ici (contrairement au rapport
    // individuel) : sans limite, un rapport classe entiere charge en memoire
    // les photos de tous les eleves simultanement avant que le document ne
    // soit rendu, ce qui peut faire planter l'appli sur une classe nombreuse
    // avec beaucoup d'observations photographiees.
    const maxPhotosPerChildInClassReport = 4;
    for (final child in children) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (context) => buildChildReport(
            child: child,
            provider: provider,
            from: from,
            to: to,
            onlyLatestPerAtelier: onlyLatestPerAtelier,
            maxPhotosPerChild: maxPhotosPerChildInClassReport,
          ),
        ),
      );
    }

    return doc.save();
  }
}
