import 'dart:io';
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

  Widget _buildChildAvatar(Child child) {
    if (child.imagePath != null && child.imagePath!.isNotEmpty && File(child.imagePath!).existsSync()) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: FileImage(File(child.imagePath!)),
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
                    leading: _buildChildAvatar(child),
                    title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(child.group ?? 'Sans groupe'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4E9F3D)),
                          onPressed: () => _generateAndShareReport(context, child, provider),
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
    String? selectedImagePath = child?.imagePath;

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
                  onPressed: () {
                    if (firstnameController.text.trim().isEmpty) return;
                    final newChild = Child(
                      id: child?.id ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
                      firstname: firstnameController.text.trim(),
                      lastname: lastnameController.text.trim(),
                      group: groupController.text.trim(),
                      notes: notesController.text.trim(),
                      email: emailController.text.trim(),
                      colorHex: child?.colorHex ?? '#4E9F3D',
                      avatarText: firstnameController.text.trim()[0].toUpperCase(),
                      imagePath: selectedImagePath,
                    );
                    provider.addOrUpdateChild(newChild);
                    Navigator.pop(context);
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

  Future<void> _generateAndShareReport(BuildContext context, Child child, AppStateProvider provider) async {
    final childLogs = provider.activities.where((log) => log.childId == child.id).toList();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rapport d\'activités - PetitPas', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Élève : ${_sanitizeEmoji(child.firstname)} ${_sanitizeEmoji(child.lastname ?? "")}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            if (child.group != null && child.group!.isNotEmpty)
              pw.Text('Groupe/Section : ${_sanitizeEmoji(child.group!)}', style: const pw.TextStyle(fontSize: 12)),
            if (child.email != null && child.email!.isNotEmpty)
              pw.Text('Email de contact : ${child.email}', style: const pw.TextStyle(fontSize: 12)),
            if (child.notes != null && child.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Notes : ${_sanitizeEmoji(child.notes!)}', style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
            ],
            pw.SizedBox(height: 20),
            pw.Text('Historique des activités :', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            if (childLogs.isEmpty)
              pw.Text('Aucune activité enregistrée pour cet élève.')
            else
              ...childLogs.map((log) {
                final actType = provider.activityTypes.firstWhere(
                  (a) => a.id == log.activityTypeId,
                  orElse: () => ActivityType(id: '', name: 'Atelier inconnu', category: '', iconName: '', colorHex: ''),
                );
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
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
                          pw.Text(_sanitizeEmoji(actType.name), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(_sanitizeEmoji(log.emotion)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
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
                        pw.Text('Statut : ${_sanitizeEmoji(log.evaluationStatus!)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      ],
                      if (log.note != null && log.note!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(_sanitizeEmoji(log.note!), style: const pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
                      ],
                    ],
                  ),
                );
              }).toList(),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    final filename = 'Rapport_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_');

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Rapport de ${child.firstname}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destinataire : ${child.email != null && child.email!.isNotEmpty ? child.email : "Aucun email renseigné"}'),
                const SizedBox(height: 12),
                const Text('Vous pouvez partager ce PDF par mail, l\'imprimer ou le sauvegarder.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Partager / Email'),
                onPressed: () async {
                  Navigator.pop(context);
                  await Printing.sharePdf(bytes: bytes, filename: filename);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Printing.layoutPdf(onLayout: (format) => bytes);
                },
              ),
            ],
          );
        },
      );
    }
  }
}
