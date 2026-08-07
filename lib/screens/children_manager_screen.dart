import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';

class ChildrenManagerScreen extends StatelessWidget {
  const ChildrenManagerScreen({super.key});

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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.children.length,
        itemBuilder: (context, index) {
          final child = provider.children[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
                child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
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
                    onPressed: () => provider.deleteChild(child.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChildDialog(BuildContext context, AppStateProvider provider, {Child? child}) {
    final firstnameController = TextEditingController(text: child?.firstname ?? '');
    final lastnameController = TextEditingController(text: child?.lastname ?? '');
    final groupController = TextEditingController(text: child?.group ?? '');
    final notesController = TextEditingController(text: child?.notes ?? '');
    final emailController = TextEditingController(text: child?.email ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(child == null ? 'Ajouter un Élève' : 'Modifier Élève'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstnameController, decoration: const InputDecoration(labelText: 'Prénom *')),
                const SizedBox(height: 10),
                TextField(controller: lastnameController, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 10),
                TextField(controller: groupController, decoration: const InputDecoration(labelText: 'Groupe / Section')),
                const SizedBox(height: 10),
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
            pw.Text('Élève : ${child.firstname} ${child.lastname ?? ""}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            if (child.group != null && child.group!.isNotEmpty)
              pw.Text('Groupe/Section : ${child.group}', style: const pw.TextStyle(fontSize: 12)),
            if (child.email != null && child.email!.isNotEmpty)
              pw.Text('Email de contact : ${child.email}', style: const pw.TextStyle(fontSize: 12)),
            if (child.notes != null && child.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Notes : ${child.notes}', style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
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
                          pw.Text(actType.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(log.emotion),
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
                          pw.Text(actType.category, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                      if (log.note != null && log.note!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(log.note!, style: const pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
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
