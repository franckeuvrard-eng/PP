import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../providers/app_provider.dart';
import '../services/atelier_pdf_service.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import 'atelier_edit_screen.dart';

/// Fiche en lecture seule d'un atelier : la liste des ateliers dans les
/// réglages ne montre plus que l'essentiel, tout le détail est ici, à un tap.
class AtelierDetailScreen extends StatelessWidget {
  final ActivityType atelier;

  const AtelierDetailScreen({super.key, required this.atelier});

  void _confirmDelete(BuildContext context, AppStateProvider provider, ActivityType current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet atelier ?'),
        content: Text('« ${current.name} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteActivityType(current.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, _) {
        final current = provider.activityTypeById(atelier.id) ?? atelier;
        final space = provider.spaceById(current.spaceId);
        final color = hexToColor(current.colorHex);

        return Scaffold(
          appBar: AppBar(
            title: Text(current.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Exporter la fiche PDF',
                onPressed: () => AtelierPdfService.openPreview(context, provider, current),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Modifier',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AtelierEditScreen(activityType: current)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Supprimer',
                onPressed: () => _confirmDelete(context, provider, current),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: color,
                      child: Icon(iconForName(current.iconName, fallback: Icons.palette), color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          if (space != null)
                            Text(space.name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (current.isObligatory)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      current.obligatoryGroups.isEmpty
                          ? '⭐ Obligatoire · toute la classe'
                          : '⭐ Obligatoire · ${current.obligatoryGroups.join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                if (current.domaine.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Domaine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 4),
                  Text('📚 ${current.domaine}'),
                ],
                if (current.objectifs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Objectifs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 4),
                  ...current.objectifs.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $o'),
                      )),
                ],
                if (current.description != null && current.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 4),
                  Text(current.description!.trim()),
                ],
                if (current.allPhotoPaths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kMutedTextColor)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: current.allPhotoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final relPath = current.allPhotoPaths[index];
                        final absPath = provider.getAbsolutePath(relPath);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: absPath != null && File(absPath).existsSync()
                              ? Image.file(File(absPath), width: 96, height: 96, fit: BoxFit.cover)
                              : Container(
                                  width: 96,
                                  height: 96,
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  child: const Icon(Icons.broken_image, size: 24),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
