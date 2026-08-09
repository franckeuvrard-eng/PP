import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../data/sons_data.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';
import 'child_profile_screen.dart';

enum ChildFilterMode { all, pendingToday, evaluatedToday }

class ChildrenManagerScreen extends StatefulWidget {
  const ChildrenManagerScreen({super.key});

  @override
  State<ChildrenManagerScreen> createState() => _ChildrenManagerScreenState();
}

class _ChildrenManagerScreenState extends State<ChildrenManagerScreen> {
  String _searchQuery = '';
  ChildFilterMode _filterMode = ChildFilterMode.all;

  Widget _buildChildAvatar(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    if (absolutePath != null && File(absolutePath).existsSync()) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: FileImage(File(absolutePath)),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
      child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final now = DateTime.now();

    final allChildren = provider.children;

    // Calculate today activity counts per child
    final Map<String, int> todayActivityCounts = {};
    for (var child in allChildren) {
      final count = provider.activities.where((act) => act.childId == child.id && _isSameDay(act.timestamp, now)).length;
      todayActivityCounts[child.id] = count;
    }

    final pendingTodayCount = allChildren.where((c) => (todayActivityCounts[c.id] ?? 0) == 0).length;
    final evaluatedTodayCount = allChildren.where((c) => (todayActivityCounts[c.id] ?? 0) > 0).length;

    // Filter list
    final filteredChildren = allChildren.where((child) {
      // 1. Text Search
      final nameMatches = '${child.firstname} ${child.lastname ?? ""}'.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (child.group ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      // 2. Status Filter
      final todayCount = todayActivityCounts[child.id] ?? 0;
      if (_filterMode == ChildFilterMode.pendingToday && todayCount > 0) return false;
      if (_filterMode == ChildFilterMode.evaluatedToday && todayCount == 0) return false;

      return true;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChildDialog(context, provider),
        backgroundColor: const Color(0xFF4E9F3D),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter Élève', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── SEARCH & FILTER HEADER ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un élève, groupe...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Tous (${allChildren.length})'),
                        selected: _filterMode == ChildFilterMode.all,
                        selectedColor: const Color(0xFF4E9F3D).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF4E9F3D),
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.all),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('⏳ En attente ($pendingTodayCount)'),
                        selected: _filterMode == ChildFilterMode.pendingToday,
                        selectedColor: Colors.amber.withOpacity(0.2),
                        checkmarkColor: Colors.amber.shade900,
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.pendingToday),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('✅ Évalués aujourd\'hui ($evaluatedTodayCount)'),
                        selected: _filterMode == ChildFilterMode.evaluatedToday,
                        selectedColor: const Color(0xFF4E9F3D).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF4E9F3D),
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.evaluatedToday),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CHILDREN LIST ──
          Expanded(
            child: filteredChildren.isEmpty
                ? const Center(
                    child: Text('Aucun élève ne correspond à la recherche.'),
                  )
                : ListView.builder(
                    // Marge basse degagee pour le bouton flottant, qui
                    // recouvrait sinon la derniere fiche de la liste.
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filteredChildren.length,
                    itemBuilder: (context, index) {
                      final child = filteredChildren[index];
                      final todayCount = todayActivityCounts[child.id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildProfileScreen(child: child),
                              ),
                            );
                          },
                          leading: _buildChildAvatar(child, provider),
                          title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(child.group ?? 'Sans groupe', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              todayCount > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4E9F3D).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✅ $todayCount activité(s) aujourd\'hui',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D)),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⏳ En attente d\'activité',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4E9F3D)),
                                onPressed: () => _choosePdfPeriod(context, child, provider),
                                tooltip: 'Générer le rapport PDF',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── PDF PERIOD PICKER ───────────────────
  void _choosePdfPeriod(BuildContext context, Child child, AppStateProvider provider) {
    DateTimeRange? customRange;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.date_range, color: Color(0xFF4E9F3D)),
                  SizedBox(width: 8),
                  Text('Période du rapport'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choisissez la période à inclure dans le rapport PDF :',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  _periodButton(
                    context: context,
                    label: 'Toute la période',
                    icon: Icons.all_inclusive,
                    onTap: () {
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider, null, null);
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: 'Ce mois-ci',
                    icon: Icons.calendar_month,
                    onTap: () {
                      final now = DateTime.now();
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider,
                          DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: 'Semaine en cours',
                    icon: Icons.view_week,
                    onTap: () {
                      final now = DateTime.now();
                      final monday = now.subtract(Duration(days: now.weekday - 1));
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider,
                          DateTime(monday.year, monday.month, monday.day),
                          DateTime(monday.year, monday.month, monday.day + 6, 23, 59));
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: customRange != null
                        ? '${DateFormat('dd/MM').format(customRange!.start)} → ${DateFormat('dd/MM').format(customRange!.end)}'
                        : 'Période personnalisée…',
                    icon: Icons.tune,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) {
                        setDialogState(() => customRange = picked);
                      }
                    },
                  ),
                  if (customRange != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openPdfPreview(context, child, provider, customRange!.start,
                              customRange!.end.add(const Duration(days: 1)));
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Générer le PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E9F3D),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _periodButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ─────────────────── ADD/EDIT CHILD DIALOG ───────────────────
  void _openChildDialog(BuildContext context, AppStateProvider provider, {Child? child}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChildFormDialog(provider: provider, child: child),
      ),
    );
  }

  // ─────────────────── PDF PREVIEW ───────────────────

  Future<void> _openPdfPreview(
    BuildContext context,
    Child child,
    AppStateProvider provider,
    DateTime? from,
    DateTime? to,
  ) async {
    String periodLabel = 'Toute la période';
    if (from != null && to != null) {
      periodLabel = '${DateFormat('dd/MM/yyyy').format(from)} → ${DateFormat('dd/MM/yyyy').format(to.subtract(const Duration(days: 1)))}';
    }

    openPdfViewer(
      context,
      title: 'Rapport - ${child.firstname} ($periodLabel)',
      fileName: 'Rapport_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
      build: (format) => _generateReportBytes(child, provider, format, from, to),
      shareBody: 'Veuillez trouver ci-joint le rapport d\'activités de ${child.firstname}.',
      shareSubject: 'Rapport d\'activités - ${child.firstname}',
      shareEmails: child.email != null && child.email!.isNotEmpty ? [child.email!] : null,
    );
  }

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
          fontSize: 10,
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

  List<pw.Widget> _buildSonsSection(Child child, AppStateProvider provider) {
    final tous = SonsData.tous;
    final acquis = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.acquis).length;
    final enCours = tous.where((s) => provider.sonStatut(child.id, s) == SonStatut.enCours).length;

    return [
      pw.Text('Analyse des sons — état actuel',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text(
        'Langage · conscience phonémique & signes graphiques — $acquis acquis, $enCours en cours sur ${tous.length} sons.',
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

  Future<Uint8List> _generateReportBytes(
    Child child,
    AppStateProvider provider,
    PdfPageFormat format,
    DateTime? from,
    DateTime? to,
  ) async {
    // Filter logs by period
    var childLogs = provider.activities.where((log) => log.childId == child.id).toList();
    if (from != null) {
      childLogs = childLogs.where((l) => l.timestamp.isAfter(from.subtract(const Duration(seconds: 1)))).toList();
    }
    if (to != null) {
      childLogs = childLogs.where((l) => l.timestamp.isBefore(to)).toList();
    }
    childLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final doc = pw.Document();

    // Profile photo bytes
    pw.MemoryImage? profileImage;
    final profilePath = provider.getAbsolutePath(child.imagePath);
    if (profilePath != null && File(profilePath).existsSync()) {
      profileImage = pw.MemoryImage(File(profilePath).readAsBytesSync());
    }

    final periodLabel = (from != null && to != null)
        ? '${DateFormat('dd/MM/yyyy').format(from)} → ${DateFormat('dd/MM/yyyy').format(to.subtract(const Duration(days: 1)))}'
        : 'Toute la période';

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rapport d\'activités - PetitPas',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Période : ${pdfSafe(periodLabel)}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
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
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.email != null && child.email!.isNotEmpty)
                      pw.Text('Email de contact : ${pdfSafe(child.email ?? "")}',
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
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
                final actType = provider.activityTypes.firstWhere(
                  (a) => a.id == log.activityTypeId,
                  orElse: () =>
                      ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: '#718096'),
                );

                final space = provider.spaces.firstWhere(
                  (s) => s.id == actType.spaceId,
                  orElse: () => Space(id: '', name: '', colorHex: ''),
                );

                final List<pw.MemoryImage> activityImages = [];
                for (final path in log.photoPaths) {
                  final resolvedPath = provider.getAbsolutePath(path);
                  if (resolvedPath != null && File(resolvedPath).existsSync()) {
                    activityImages.add(pw.MemoryImage(File(resolvedPath).readAsBytesSync()));
                  }
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
                      if (log.evaluationStatus != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Statut : ${pdfSafe(log.evaluationStatus!)}',
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
                          children: activityImages.map((img) {
                            return pw.Container(
                              width: 70,
                              height: 70,
                              decoration: const pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                                color: PdfColors.grey100,
                              ),
                              child: pw.Image(img, fit: pw.BoxFit.cover),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
          ];
        },
      ),
    );

    return doc.save();
  }
}

// ─── Proper StatefulWidget for Child form dialog ───
class ChildFormDialog extends StatefulWidget {
  final AppStateProvider provider;
  final Child? child;

  const ChildFormDialog({super.key, required this.provider, this.child});

  @override
  State<ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<ChildFormDialog> {
  late final TextEditingController _firstnameController;
  late final TextEditingController _lastnameController;
  late final TextEditingController _groupController;
  late final TextEditingController _notesController;
  late final TextEditingController _emailController;
  String? _relativeImagePath;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    final child = widget.child;
    final provider = widget.provider;
    _firstnameController = TextEditingController(text: child?.firstname ?? '');
    _lastnameController = TextEditingController(text: child?.lastname ?? '');
    _groupController = TextEditingController(text: child?.group ?? 'Petite Section (PS)');
    _notesController = TextEditingController(text: child?.notes ?? '');
    _emailController = TextEditingController(text: child?.email ?? '');
    _relativeImagePath = child?.imagePath;
    _selectedImagePath = provider.getAbsolutePath(child?.imagePath);
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _groupController.dispose();
    _notesController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final relPath = await widget.provider.pickAndSavePhoto(
      source: source,
      subDir: 'profiles',
    );
    if (relPath != null && mounted) {
      setState(() {
        _relativeImagePath = relPath;
        _selectedImagePath = widget.provider.getAbsolutePath(relPath);
      });
    }
  }

  bool get _hasValidImage {
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) return false;
    return File(_selectedImagePath!.replaceFirst('file://', '')).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final provider = widget.provider;

    return Scaffold(
      appBar: AppBar(
        title: Text(child == null ? 'Ajouter un Élève' : 'Modifier Élève'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar / Photo Selection
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickPhoto(ImageSource.gallery),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _hasValidImage
                          ? FileImage(File(_selectedImagePath!.replaceFirst('file://', '')))
                          : null,
                      child: !_hasValidImage
                          ? const Icon(Icons.add_a_photo, size: 28, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.photo_camera, size: 14),
                    label: const Text('Appareil photo', style: TextStyle(fontSize: 12)),
                    onPressed: () => _pickPhoto(ImageSource.camera),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _firstnameController, decoration: const InputDecoration(labelText: 'Prénom *')),
            const SizedBox(height: 10),
            TextField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 14),

            // Group/Section ComboBox Dropdown
            DropdownButtonFormField<String>(
              value: ['Petite Section (PS)', 'Moyenne Section (MS)', 'Grande Section (GS)', 'Groupe Rouge', 'Groupe Bleu', 'Groupe Jaune', 'Groupe Vert'].contains(_groupController.text)
                  ? _groupController.text
                  : 'Petite Section (PS)',
              decoration: const InputDecoration(labelText: 'Groupe / Section', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Petite Section (PS)', child: Text('Petite Section (PS)')),
                DropdownMenuItem(value: 'Moyenne Section (MS)', child: Text('Moyenne Section (MS)')),
                DropdownMenuItem(value: 'Grande Section (GS)', child: Text('Grande Section (GS)')),
                DropdownMenuItem(value: 'Groupe Rouge', child: Text('Groupe Rouge')),
                DropdownMenuItem(value: 'Groupe Bleu', child: Text('Groupe Bleu')),
                DropdownMenuItem(value: 'Groupe Jaune', child: Text('Groupe Jaune')),
                DropdownMenuItem(value: 'Groupe Vert', child: Text('Groupe Vert')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _groupController.text = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email des parents')),
            const SizedBox(height: 10),
            TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes (Allergies, etc.)')),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_firstnameController.text.trim().isEmpty) return;

                  final newChild = Child(
                    id: child?.id ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
                    firstname: _firstnameController.text.trim(),
                    lastname: _lastnameController.text.trim(),
                    group: _groupController.text.trim(),
                    notes: _notesController.text.trim(),
                    email: _emailController.text.trim(),
                    colorHex: child?.colorHex ?? '#4E9F3D',
                    avatarText: _firstnameController.text.trim()[0].toUpperCase(),
                    imagePath: _relativeImagePath,
                  );
                  provider.addOrUpdateChild(newChild);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
