import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';

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
                    leading: _buildChildAvatar(child, provider),
                    title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(child.group ?? 'Sans groupe'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4E9F3D)),
                          onPressed: () => _openPdfPreview(context, child, provider),
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

  void _openChildDialog(BuildContext context, AppStateProvider provider, {Child? child}) {
    final firstnameController = TextEditingController(text: child?.firstname ?? '');
    final lastnameController = TextEditingController(text: child?.lastname ?? '');
    final groupController = TextEditingController(text: child?.group ?? 'Petite Section (PS)');
    final notesController = TextEditingController(text: child?.notes ?? '');
    final emailController = TextEditingController(text: child?.email ?? '');
    String? selectedImagePath = provider.getAbsolutePath(child?.imagePath);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(child == null ? 'Ajouter un Élève' : 'Modifier Élève'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar / Photo Selection
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                setDialogState(() {
                                  selectedImagePath = image.path;
                                });
                              }
                            },
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: (selectedImagePath != null && selectedImagePath!.isNotEmpty && File(selectedImagePath!).existsSync())
                                  ? FileImage(File(selectedImagePath!))
                                  : null,
                              child: (selectedImagePath == null || selectedImagePath!.isEmpty || !File(selectedImagePath!).existsSync())
                                  ? const Icon(Icons.add_a_photo, size: 28, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            icon: const Icon(Icons.photo_camera, size: 14),
                            label: const Text('Appareil photo', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.camera);
                              if (image != null) {
                                setDialogState(() {
                                  selectedImagePath = image.path;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: firstnameController, decoration: const InputDecoration(labelText: 'Prénom *')),
                    const SizedBox(height: 10),
                    TextField(controller: lastnameController, decoration: const InputDecoration(labelText: 'Nom')),
                    const SizedBox(height: 14),
                    
                    // Group/Section ComboBox Dropdown
                    DropdownButtonFormField<String>(
                      value: ['Petite Section (PS)', 'Moyenne Section (MS)', 'Grande Section (GS)', 'Groupe Rouge', 'Groupe Bleu', 'Groupe Jaune', 'Groupe Vert'].contains(groupController.text)
                          ? groupController.text
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
                          groupController.text = val;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email des parents')),
                    const SizedBox(height: 10),
                    TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes (Allergies, etc.)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    if (firstnameController.text.trim().isEmpty) return;

                    // Handle persistent image copy if changed
                    String? relativeImagePath = child?.imagePath;
                    if (selectedImagePath != null && selectedImagePath != provider.getAbsolutePath(child?.imagePath)) {
                      relativeImagePath = await provider.saveImageToDocs(selectedImagePath!, 'profiles');
                    }

                    final newChild = Child(
                      id: child?.id ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
                      firstname: firstnameController.text.trim(),
                      lastname: lastnameController.text.trim(),
                      group: groupController.text.trim(),
                      notes: notesController.text.trim(),
                      email: emailController.text.trim(),
                      colorHex: child?.colorHex ?? '#4E9F3D',
                      avatarText: firstnameController.text.trim()[0].toUpperCase(),
                      imagePath: relativeImagePath,
                    );
                    provider.addOrUpdateChild(newChild);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Sanitizes emojis from PDF text to avoid rendering crashes
  String _sanitizeEmoji(String text) {
    return text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}|\u{1F900}-\u{1F9FF}|\u{1F1E0}-\u{1F1FF}]', unicode: true), '').trim();
  }

  Future<void> _openPdfPreview(BuildContext context, Child child, AppStateProvider provider) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Aperçu du Rapport - ${child.firstname}'),
            backgroundColor: const Color(0xFF4E9F3D),
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) => _generateReportBytes(child, provider),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: 'Rapport_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
            shareActionExtraBody: 'Veuillez trouver ci-joint le rapport d\'activités de ${child.firstname}.',
            shareActionExtraSubject: 'Rapport d\'activités - ${child.firstname}',
            // Auto fill destination email if present
            shareActionExtraEmails: child.email != null && child.email!.isNotEmpty ? [child.email!] : null,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateReportBytes(Child child, AppStateProvider provider) async {
    final childLogs = provider.activities.where((log) => log.childId == child.id).toList();
    final doc = pw.Document();

    // Profile photo bytes
    pw.MemoryImage? profileImage;
    final profilePath = provider.getAbsolutePath(child.imagePath);
    if (profilePath != null && File(profilePath).existsSync()) {
      profileImage = pw.MemoryImage(File(profilePath).readAsBytesSync());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header with title and logo preview if exists
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rapport d\'activités - PetitPas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Profile info row with child avatar
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Élève : ${_sanitizeEmoji(child.firstname)} ${_sanitizeEmoji(child.lastname ?? "")}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    if (child.group != null && child.group!.isNotEmpty)
                      pw.Text('Groupe/Section : ${_sanitizeEmoji(child.group!)}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.email != null && child.email!.isNotEmpty)
                      pw.Text('Email de contact : ${child.email}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    if (child.notes != null && child.notes!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Notes : ${_sanitizeEmoji(child.notes!)}', style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
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
                    clipBehavior: pw.Clip.antiAlias,
                    child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                  ),
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Text('Historique des activités :', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 8),

            if (childLogs.isEmpty)
              pw.Text('Aucune activité enregistrée pour cet élève.', style: const pw.TextStyle(fontSize: 11))
            else
              ...childLogs.map((log) {
                final actType = provider.activityTypes.firstWhere(
                  (a) => a.id == log.activityTypeId,
                  orElse: () => ActivityType(id: '', name: 'Atelier inconnu', category: '', iconName: '', colorHex: ''),
                );

                // Load associated photos bytes
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
                          pw.Text(_sanitizeEmoji(actType.name), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text(_sanitizeEmoji(log.emotion), style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                          ),
                          pw.Text(_sanitizeEmoji(actType.category), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                      if (log.evaluationStatus != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Statut : ${_sanitizeEmoji(log.evaluationStatus!)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      ],
                      if (log.note != null && log.note!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(_sanitizeEmoji(log.note!), style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                      ],

                      // Grid display of activity images
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
                              clipBehavior: pw.Clip.antiAlias,
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
