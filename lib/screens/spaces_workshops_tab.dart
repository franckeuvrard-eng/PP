import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import 'atelier_detail_screen.dart';
import 'atelier_edit_screen.dart';

/// Onglet « Espaces & Ateliers » de l'écran Réglages : CRUD des espaces de la
/// classe et de leurs ateliers, réordonnancement en mode progression.
class SpacesWorkshopsTab extends StatelessWidget {
  const SpacesWorkshopsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final spaces = provider.spaces;
    final allAteliers = provider.activityTypes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION ESPACES ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📍 Espaces de la Classe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _openSpaceDialog(context, provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Espace'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Définissez les zones / coins de votre classe.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          // Spaces list
          ...spaces.map((space) {
            final ateliersInSpace = allAteliers.where((a) => a.spaceId == space.id).toList();
            final spaceColor = hexToColor(space.colorHex);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: spaceColor.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: spaceColor,
                  child: Icon(iconForName(space.iconName, fallback: Icons.space_dashboard),
                      color: Colors.white, size: 22),
                ),
                title: Text(space.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge('${ateliersInSpace.length} atelier(s)', spaceColor),
                          if (space.isProgression) _badge('🔒 Progression', Colors.deepOrange),
                        ],
                      ),
                      if (space.description != null && space.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          space.description!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                      onPressed: () => _openSpaceDialog(context, provider, space: space),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer cet espace ?'),
                            content: Text('Cela supprimera aussi les ${ateliersInSpace.length} atelier(s) rattachés.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () {
                                  provider.deleteSpace(space.id);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                children: [
                  // Ateliers in this space : glisser-deposer si l'espace impose
                  // un ordre de progression, sinon liste condensee simple.
                  if (space.isProgression)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        final ordered = provider.ateliersInSpaceOrdered(space.id).map((a) => a.id).toList();
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = ordered.removeAt(oldIndex);
                        ordered.insert(newIndex, id);
                        provider.reorderAteliersInSpace(space.id, ordered);
                      },
                      children: [
                        for (final entry in provider.ateliersInSpaceOrdered(space.id).asMap().entries)
                          _buildAtelierTile(context, provider, entry.value,
                              key: ValueKey(entry.value.id), dragIndex: entry.key),
                      ],
                    )
                  else
                    ...ateliersInSpace.map((atelier) => _buildAtelierTile(context, provider, atelier)),
                  // Add atelier button inside expansion
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: () => _openActivityTypeDialog(context, provider, preselectedSpaceId: space.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un atelier dans cet espace'),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (spaces.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Aucun espace défini. Ajoutez votre premier espace !')),
            ),
        ],
      ),
    );
  }

  /// Petite pastille arrondie (nombre d'ateliers, mode progression...) pour
  /// distinguer les espaces d'un coup d'œil sans avoir à les déplier.
  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// Ligne condensee d'un atelier : le detail (domaine, objectifs, photos,
  /// obligatoire) est dans AtelierDetailScreen, a un tap. [dragIndex] non nul
  /// affiche une poignee de glisser-deposer au lieu du chevron (mode
  /// progression) ; le tap reste dedie a l'ouverture du detail dans les deux cas.
  Widget _buildAtelierTile(
    BuildContext context,
    AppStateProvider provider,
    ActivityType atelier, {
    Key? key,
    int? dragIndex,
  }) {
    return ListTile(
      key: key,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: hexToColor(atelier.colorHex),
        child: Icon(iconForName(atelier.iconName, fallback: Icons.palette), size: 14, color: Colors.white),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(atelier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (atelier.isObligatory)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.stars, size: 15, color: Colors.orange),
            ),
        ],
      ),
      subtitle: atelier.domaine.isEmpty && atelier.objectifs.isEmpty
          ? null
          : Text(
              [
                if (atelier.domaine.isNotEmpty) '📚 ${atelier.domaine}',
                if (atelier.objectifs.isNotEmpty) '🏁 ${atelier.objectifs.length} objectif(s)',
              ].join('  •  '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
      trailing: dragIndex != null
          ? ReorderableDragStartListener(
              index: dragIndex,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AtelierDetailScreen(atelier: atelier)),
      ),
    );
  }

  // ─────────────────── SPACE DIALOG ───────────────────
  void _openSpaceDialog(BuildContext context, AppStateProvider provider, {Space? space}) {
    final nameCtrl = TextEditingController(text: space?.name ?? '');
    final descCtrl = TextEditingController(text: space?.description ?? '');
    String color = space?.colorHex ?? '#4E9F3D';
    String? iconName = space?.iconName;
    bool isProgression = space?.isProgression ?? false;
    String? progressionMinStatusId = space?.progressionMinStatusId ??
        (provider.evaluationStatuses.isNotEmpty ? provider.evaluationStatuses.last.id : null);

    final colors = ['#FF7043', '#4E9F3D', '#7E57C2', '#FFA726', '#42A5F5', '#8D6E63', '#E91E63', '#00BCD4', '#673AB7', '#FF5722'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: Text(space == null ? 'Ajouter un Espace' : 'Modifier l\'Espace'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de l\'espace')),
                    const SizedBox(height: 8),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Couleur :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((c) {
                        final isSelected = c == color;
                        return GestureDetector(
                          onTap: () => setSt(() => color = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hexToColor(c),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: hexToColor(c), blurRadius: 8)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Icône :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: hexToColor(color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconForName(iconName, fallback: Icons.space_dashboard),
                            color: hexToColor(color),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showAppIconPicker(context, iconName);
                              if (picked != null) {
                                setSt(() => iconName = picked.isEmpty ? null : picked);
                              }
                            },
                            icon: const Icon(Icons.emoji_symbols),
                            label: Text(iconName == null ? 'Choisir' : iconName!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mode progression (ordre imposé)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text(
                        "Les ateliers de cet espace doivent être faits dans l'ordre : un atelier reste verrouillé tant que les précédents n'ont pas atteint le statut minimum choisi.",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isProgression,
                      activeColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setSt(() => isProgression = val),
                    ),
                    if (isProgression && provider.evaluationStatuses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "⚠️ Aucun niveau d'évaluation n'existe : aucun atelier ne pourra jamais être débloqué. Créez-en au moins un dans Réglages.",
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isProgression && provider.evaluationStatuses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: provider.evaluationStatuses.any((s) => s.id == progressionMinStatusId)
                            ? progressionMinStatusId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Statut minimum pour débloquer le suivant',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: provider.evaluationStatuses.map((s) {
                          return DropdownMenuItem(value: s.id, child: Text(s.label));
                        }).toList(),
                        onChanged: (val) => setSt(() => progressionMinStatusId = val),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      final newSpace = Space(
                        id: space?.id ?? 'space_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        colorHex: color,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        iconName: iconName,
                        isProgression: isProgression,
                        progressionMinStatusId: isProgression ? progressionMinStatusId : space?.progressionMinStatusId,
                      );
                      provider.addOrUpdateSpace(newSpace);
                      if (isProgression) {
                        provider.setSpaceProgression(newSpace.id, true, minStatusId: progressionMinStatusId);
                      }
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

  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider, {ActivityType? activityType, String? preselectedSpaceId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AtelierEditScreen(
          activityType: activityType,
          preselectedSpaceId: preselectedSpaceId,
        ),
      ),
    );
  }
}
