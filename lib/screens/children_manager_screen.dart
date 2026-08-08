import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/activity.dart';

class ChildrenManagerScreen extends StatelessWidget {
  const ChildrenManagerScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChildDialog(context, provider),
        backgroundColor: const Color(0xFF4E9F3D),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter Élève', style: TextStyle(color: Colors.white)),
      ),
      body: provider.children.isEmpty
          ? const Center(
              child: Text('Aucun élève enregistré. Ajoutez-en un !'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.children.length,
              itemBuilder: (context, index) {
                final child = provider.children[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    onTap: () => _showChildHistoryDialog(context, provider, child),
                    leading: _buildChildAvatar(child, provider),
                    title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(child.group ?? 'Sans groupe'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4E9F3D)),
                          onPressed: () => _choosePdfPeriod(context, child, provider),
                          tooltip: 'Générer le rapport PDF',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF718096)),
                          onPressed: () => _openChildDialog(context, provider, child: child),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteChild(context, provider, child),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─────────────────── HISTORY POPUP ───────────────────
  void _showChildHistoryDialog(BuildContext context, AppStateProvider provider, Child child) {
    final childLogs = provider.activities.where((log) => log.childId == child.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF4E9F3D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    _buildChildAvatarSmall(child, provider),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${child.firstname} ${child.lastname ?? ""}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (child.group != null)
                            Text(child.group!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Logs list
              Flexible(
                child: childLogs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Aucune activité enregistrée.', textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: childLogs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = childLogs[index];
                          final actType = provider.activityTypes.firstWhere(
                            (a) => a.id == log.activityTypeId,
                            orElse: () => ActivityType(id: '', name: 'Atelier inconnu', category: '', iconName: '', colorHex: '#718096'),
                          );
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                              child: const Icon(Icons.palette, size: 14, color: Colors.white),
                            ),
                            title: Text(actType.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFA0AEC0))),
                                if (log.evaluationStatus != null)
                                  Text(log.evaluationStatus!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                if (log.note != null && log.note!.isNotEmpty)
                                  Text(log.note!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),

              // Export Excel button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportToExcel(context, provider, child, childLogs);
                    },
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Exporter en Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF217346),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChildAvatarSmall(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    if (absolutePath != null && File(absolutePath).existsSync()) {
      return CircleAvatar(radius: 22, backgroundImage: FileImage(File(absolutePath)));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white.withOpacity(0.3),
      child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ─────────────────── EXCEL EXPORT ───────────────────
  Future<void> _exportToExcel(
    BuildContext context,
    AppStateProvider provider,
    Child child,
    List<ActivityLog> logs,
  ) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Activités'];
      excel.setDefaultSheet('Activités');

      // Header row
      sheet.appendRow([
        xl.TextCellValue('Date'),
        xl.TextCellValue('Atelier'),
        xl.TextCellValue('Catégorie'),
        xl.TextCellValue('Statut'),
        xl.TextCellValue('Observation'),
      ]);

      // Data rows
      for (final log in logs) {
        final actType = provider.activityTypes.firstWhere(
          (a) => a.id == log.activityTypeId,
          orElse: () => ActivityType(id: '', name: 'Inconnu', category: '', iconName: '', colorHex: ''),
        );
        sheet.appendRow([
          xl.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)),
          xl.TextCellValue(actType.name),
          xl.TextCellValue(actType.category),
          xl.TextCellValue(log.evaluationStatus ?? ''),
          xl.TextCellValue(log.note ?? ''),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Erreur encodage Excel');

      final tempDir = await getTemporaryDirectory();
      final filename = 'PetitPas_${child.firstname}_${child.lastname ?? ""}_${DateTime.now().millisecondsSinceEpoch}.xlsx'
          .replaceAll(' ', '_');
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Rapport Excel — ${child.firstname}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export Excel : $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  // ─────────────────── DELETE CHILD ───────────────────
  void _confirmDeleteChild(BuildContext context, AppStateProvider provider, Child child) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Confirmer la suppression'),
            ],
          ),
          content: Text('Voulez-vous vraiment supprimer l\'élève ${child.firstname} ${child.lastname ?? ""}? Cette action supprimera également tout son historique d\'activités.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                provider.deleteChild(child.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${child.firstname} a été supprimé(e).')),
                );
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────── ADD/EDIT CHILD DIALOG ───────────────────
  void _openChildDialog(BuildContext context, AppStateProvider provider, {Child? child}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ChildFormDialog(provider: provider, child: child),
      ),
    );
  }

  // ─────────────────── PDF PREVIEW ───────────────────
  String _sanitizeEmoji(String text) {
    return text
        .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}|\u{1F900}-\u{1F9FF}|\u{1F1E0}-\u{1F1FF}]',
            unicode: true), '')
        .trim();
  }

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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Rapport - ${child.firstname} ($periodLabel)'),
            backgroundColor: const Color(0xFF4E9F3D),
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) => _generateReportBytes(child, provider, format, from, to),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: 'Rapport_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
            shareActionExtraBody: 'Veuillez trouver ci-joint le rapport d\'activités de ${child.firstname}.',
            shareActionExtraSubject: 'Rapport d\'activités - ${child.firstname}',
            shareActionExtraEmails: child.email != null && child.email!.isNotEmpty ? [child.email!] : null,
          ),
        ),
      ),
    );
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
            pw.Text('Période : $periodLabel',
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
                        '${_sanitizeEmoji(child.firstname)} ${_sanitizeEmoji(child.lastname ?? "")}',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    if (child.group != null && child.group!.isNotEmpty)
                      pw.Text('Groupe/Section : ${_sanitizeEmoji(child.group!)}',
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.email != null && child.email!.isNotEmpty)
                      pw.Text('Email de contact : ${child.email}',
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.notes != null && child.notes!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Notes : ${_sanitizeEmoji(child.notes!)}',
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
                      ActivityType(id: '', name: 'Atelier inconnu', category: '', iconName: '', colorHex: ''),
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
                          pw.Text(_sanitizeEmoji(actType.name),
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text(_sanitizeEmoji(actType.category),
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      if (log.evaluationStatus != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Statut : ${_sanitizeEmoji(log.evaluationStatus!)}',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      ],
                      if (log.note != null && log.note!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(_sanitizeEmoji(log.note!),
                            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
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
class _ChildFormDialog extends StatefulWidget {
  final AppStateProvider provider;
  final Child? child;

  const _ChildFormDialog({required this.provider, this.child});

  @override
  State<_ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<_ChildFormDialog> {
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
        actions: [
          TextButton(
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
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          ],
        ),
      ),
    );
  }
}
