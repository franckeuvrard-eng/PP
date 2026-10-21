import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import 'atelier_edit_screen.dart';
import 'space_edit_screen.dart';
import 'spaces_workshops_tab.dart';

/// Onglet « Progressions » des Réglages : parcours d'ateliers à faire dans
/// l'ordre (jalons). Création / édition / suppression, et ordre des jalons
/// par glisser-déposer.
class ProgressionsSettingsTab extends StatelessWidget {
  const ProgressionsSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final progressions = provider.progressions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('🧭 Progressions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Progression'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Une progression est une suite d'ateliers (jalons) à faire dans l'ordre : "
            "un jalon se débloque quand le précédent atteint le seuil de passage.",
            style: TextStyle(fontSize: 12, color: kMutedTextColor),
          ),
          const SizedBox(height: 12),
          for (final progression in progressions)
            _ProgressionCard(progression: progression, key: ValueKey(progression.id)),
          if (progressions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Aucune progression',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Exemple : découpage — couper une bande, puis une ligne droite, '
                    'puis une courbe, puis une forme.',
                    style: TextStyle(fontSize: 13, color: kMutedTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Créer ma première progression'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E9F3D),
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

void _openEditor(BuildContext context, {Progression? progression}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => SpaceEditScreen.progression(progression: progression)),
  );
}

class _ProgressionCard extends StatelessWidget {
  const _ProgressionCard({super.key, required this.progression});

  final Progression progression;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final jalons = provider.ateliersInProgressionOrdered(progression.id);
    final color = hexToColor(progression.colorHex);
    String? threshold;
    for (final st in provider.evaluationStatuses) {
      if (st.id == progression.minStatusId) threshold = st.label;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color,
          child: Icon(iconForName(progression.iconName, fallback: Icons.timeline),
              color: Colors.white, size: 22),
        ),
        title: Text(progression.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              settingsBadge('${jalons.length} jalon(s)', color),
              if (threshold != null) settingsBadge('Seuil : $threshold', Colors.deepOrange),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
              tooltip: 'Modifier la progression',
              onPressed: () => _openEditor(context, progression: progression),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Supprimer la progression',
              onPressed: () => _confirmDelete(context, provider, jalons.length),
            ),
          ],
        ),
        children: [
          if (jalons.length > 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(children: [
                Icon(Icons.swap_vert, size: 18, color: Color(0xFF4E9F3D)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Maintenez la poignée ⠿ et glissez un jalon pour changer sa place.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor),
                  ),
                ),
              ]),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Une seule poignee, bien visible (cf. atelierSettingsTile).
            buildDefaultDragHandles: false,
            // Le jalon deplace se souleve, entoure de vert.
            proxyDecorator: (child, index, animation) => Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF4E9F3D), width: 2),
              ),
              child: child,
            ),
            // newIndex deja corrige du decalage de l'element retire.
            onReorderItem: (oldIndex, newIndex) {
              final ordered = jalons.map((a) => a.id).toList();
              final id = ordered.removeAt(oldIndex);
              ordered.insert(newIndex, id);
              provider.reorderAteliersInProgression(progression.id, ordered);
            },
            children: [
              for (final (i, atelier) in jalons.indexed)
                atelierSettingsTile(context, atelier, key: ValueKey(atelier.id), dragIndex: i),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AtelierEditScreen(preselectedProgressionId: progression.id),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter un jalon'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppStateProvider provider, int jalonCount) {
    final obs = provider.activityCountForProgression(progression.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette progression ?'),
        content: Text(
          'Cela supprimera aussi ses $jalonCount jalon(s)'
          '${obs > 0 ? ' et leurs $obs observation(s)' : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteProgression(progression.id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
