import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/referential.dart';
import '../providers/app_provider.dart';
import 'referential_edit_screen.dart';

/// Liste des référentiels personnalisés (ceintures de couleur, Montessori,
/// ou tout autre système propre à la classe) : créer, modifier, supprimer.
///
/// Aucun contenu n'est fourni par défaut — c'est à l'enseignant de définir
/// ses groupes et ses items.
class ReferentialsManagerScreen extends StatelessWidget {
  const ReferentialsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final referentials = provider.referentials;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Référentiels personnalisés'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4E9F3D),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReferentialEditScreen()),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau référentiel', style: TextStyle(color: Colors.white)),
      ),
      body: referentials.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rtl, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun référentiel pour l\'instant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez un référentiel (ceintures de couleur, base Montessori, ou '
                    'tout autre suivi) : vous définissez vous-même ses groupes et ses items.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: referentials.length,
              itemBuilder: (context, index) {
                final referential = referentials[index];
                final itemCount = referential.allItems.length;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.checklist_rtl, color: Color(0xFF4E9F3D)),
                    title: Text(referential.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${referential.groups.length} groupe(s) · $itemCount item(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Modifier',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReferentialEditScreen(referential: referential),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDelete(context, provider, referential),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, AppStateProvider provider, Referential referential) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce référentiel ?'),
        content: Text(
          'Le référentiel "${referential.name}" et le suivi de tous les élèves pour '
          'ce référentiel seront définitivement supprimés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteReferential(referential.id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
