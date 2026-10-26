import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../data/eduscol_data.dart';
import '../providers/app_provider.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import 'atelier_detail_screen.dart';
import 'atelier_edit_screen.dart';
import 'space_edit_screen.dart';

/// Page « Espaces & Ateliers » du menu principal (barre laterale sur
/// ordinateur / iPad, carte de l'accueil sur telephone), sortie des
/// Parametres pour etre a portee de main comme les Parcours.
class SpacesWorkshopsScreen extends StatelessWidget {
  const SpacesWorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espaces & Ateliers')),
      body: const SpacesWorkshopsTab(),
    );
  }
}

/// Contenu de la page Espaces & Ateliers : CRUD des espaces de la classe et
/// de leurs ateliers. Les ateliers rangés dans un parcours sont gérés dans
/// l'onglet « Parcours » des Paramètres.
class SpacesWorkshopsTab extends StatelessWidget {
  const SpacesWorkshopsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final spaces = provider.spaces;
    // Les ateliers desactives ne sont plus listes dans leur espace : ils sont
    // regroupes en bas de l'onglet, d'ou on peut les reactiver.
    final disabled = provider.activityTypes
        .where((a) => a.isDisabled && !a.inProgression)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION ESPACES ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📍 Espaces de la Classe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _openSpaceEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Espace'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Définissez les zones / coins de votre classe.',
              style: TextStyle(fontSize: 12, color: kMutedTextColor)),
          const SizedBox(height: 12),

          // Spaces list
          ...spaces.map((space) {
            final ateliersInSpace = provider.ateliersInSpace(space.id);
            final activeInSpace =
                ateliersInSpace.where((a) => !a.isDisabled).toList();
            final spaceColor = hexToColor(space.colorHex);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: spaceColor.withValues(alpha: 0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: spaceColor,
                  child: Icon(
                      iconForName(space.iconName,
                          fallback: Icons.space_dashboard),
                      color: Colors.white,
                      size: 22),
                ),
                title: Text(space.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          settingsBadge('${activeInSpace.length} atelier(s)',
                              spaceColor),
                          if (activeInSpace.length < ateliersInSpace.length)
                            settingsBadge(
                                '${ateliersInSpace.length - activeInSpace.length} désactivé(s)',
                                kMutedTextColor),
                        ],
                      ),
                      if (space.description != null &&
                          space.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          space.description!,
                          style:
                              const TextStyle(fontSize: 12, color: kMutedTextColor),
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
                      icon:
                          const Icon(Icons.edit, color: Colors.grey, size: 20),
                      tooltip: 'Modifier l\'espace',
                      onPressed: () => _openSpaceEditor(context, space: space),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      tooltip: 'Supprimer l\'espace',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer cet espace ?'),
                            content: Text(
                                'Cela supprimera aussi les ${ateliersInSpace.length} atelier(s) rattachés.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Annuler')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
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
                  ...activeInSpace.map((atelier) =>
                      atelierSettingsTile(context, atelier)),
                  // Add atelier button inside expansion
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: () => _openActivityTypeDialog(
                          context, provider,
                          preselectedSpaceId: space.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un atelier dans cet espace'),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (disabled.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.visibility_off, color: kMutedTextColor),
                title: Text('Ateliers désactivés (${disabled.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Masqués ici, toujours visibles dans les observations, rapports et statistiques.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                children: [
                  for (final atelier in disabled)
                    Row(
                      children: [
                        Expanded(child: atelierSettingsTile(context, atelier)),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton.icon(
                            onPressed: () =>
                                provider.setActivityTypeDisabled(atelier.id, false),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Réactiver'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          if (spaces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.space_dashboard_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun espace défini',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les espaces sont les zones / coins de votre classe (coin lecture, '
                    'motricité...) : créez-en un pour pouvoir y rattacher des ateliers.',
                    style: TextStyle(fontSize: 13, color: kMutedTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openSpaceEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Créer mon premier espace'),
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

  void _openSpaceEditor(BuildContext context, {Space? space}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpaceEditScreen(space: space)),
    );
  }

  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider,
      {ActivityType? activityType, String? preselectedSpaceId}) {
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

/// Petite pastille arrondie (nombre d'ateliers...) pour
/// distinguer les espaces et progressions d'un coup d'œil sans avoir à les déplier.
Widget settingsBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color)),
  );
}

/// Ligne condensee d'un atelier : le detail (domaine, objectifs, photos,
/// obligatoire) est dans AtelierDetailScreen, a un tap. [dragIndex] non nul
/// affiche une poignee de glisser-deposer au lieu du chevron (jalon
/// de progression) ; le tap reste dedie a l'ouverture du detail dans les deux cas.
Widget atelierSettingsTile(
  BuildContext context,
  ActivityType atelier, {
  Key? key,
  int? dragIndex,
}) {
  final avatar = CircleAvatar(
    radius: 16,
    backgroundColor: hexToColor(atelier.colorHex),
    child: Icon(iconForName(atelier.iconName, fallback: Icons.palette),
        size: 14, color: Colors.white),
  );
  return ListTile(
    key: key,
    dense: true,
    // En mode progression : numero d'ordre devant l'atelier.
    leading: dragIndex == null
        ? avatar
        : Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 22,
              child: Text('${dragIndex + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4E9F3D))),
            ),
            const SizedBox(width: 4),
            avatar,
          ]),
    title: Row(
      children: [
        Expanded(
          child: Text(atelier.name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              if (atelier.domaine.isNotEmpty)
                '📚 ${EduscolData.subdomainById(atelier.sousDomaineId)?.title ?? atelier.domaine}',
              if (atelier.objectifs.isNotEmpty)
                '🏁 ${atelier.objectifs.length} objectif(s)',
            ].join('  •  '),
            style: const TextStyle(fontSize: 12, color: kMutedTextColor),
          ),
    trailing: dragIndex != null
        ? ReorderableDragStartListener(
            index: dragIndex,
            child: Tooltip(
              message: "Glisser pour changer l'ordre",
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E9F3D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.drag_indicator, color: Color(0xFF4E9F3D), size: 24),
              ),
            ),
          )
        : const Icon(Icons.chevron_right, color: Colors.grey),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AtelierDetailScreen(atelier: atelier)),
    ),
  );
}
