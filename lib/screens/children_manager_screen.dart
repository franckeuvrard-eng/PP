import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';

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
}
