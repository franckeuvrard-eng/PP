import 'package:flutter/material.dart';

/// Catalogue d'icones proposees pour les espaces et les ateliers.
///
/// Les valeurs sont des constantes `Icons.*` et non des `IconData` construits
/// a partir d'un codePoint : Flutter elague les icones non referencees
/// litteralement au build (`--tree-shake-icons`), et une icone construite
/// dynamiquement s'afficherait alors comme un carre vide sur l'appareil.
const Map<String, IconData> kAppIcons = {
  // Arts et creation
  'palette': Icons.palette,
  'brush': Icons.brush,
  'colorer': Icons.format_color_fill,
  'ciseaux': Icons.content_cut,
  'photo': Icons.photo_camera,
  'theatre': Icons.theater_comedy,
  'musique': Icons.music_note,
  'piano': Icons.piano,

  // Langage et lecture
  'livre': Icons.menu_book,
  'bibliotheque': Icons.local_library,
  'ecriture': Icons.edit,
  'alphabet': Icons.abc,
  'discussion': Icons.record_voice_over,

  // Nombres et logique
  'calcul': Icons.calculate,
  'chiffres': Icons.pin,
  'formes': Icons.category,
  'puzzle': Icons.extension,
  'tri': Icons.sort,
  'balance': Icons.balance,

  // Motricite
  'course': Icons.directions_run,
  'velo': Icons.pedal_bike,
  'ballon': Icons.sports_soccer,
  'gymnastique': Icons.sports_gymnastics,
  'equilibre': Icons.accessibility_new,
  'danse': Icons.emoji_people,

  // Explorer le monde
  'nature': Icons.park,
  'jardin': Icons.local_florist,
  'animaux': Icons.pets,
  'science': Icons.science,
  'eau': Icons.water_drop,
  'sable': Icons.beach_access,
  'cuisine': Icons.restaurant,
  'meteo': Icons.wb_sunny,
  'construction': Icons.construction,
  'cubes': Icons.view_in_ar,

  // Numerique et divers
  'tablette': Icons.tablet_mac,
  'jeu': Icons.toys,
  'groupe': Icons.groups,
  'repos': Icons.bedtime,
  'hygiene': Icons.clean_hands,
  'etoile': Icons.star,
  'coeur': Icons.favorite,
  'espace': Icons.space_dashboard,
};

/// Icone correspondant a [name], ou [fallback] si la cle est inconnue ou nulle.
IconData iconForName(String? name, {IconData fallback = Icons.category}) {
  if (name == null) return fallback;
  return kAppIcons[name] ?? fallback;
}

/// Ouvre une grille de selection et renvoie la cle choisie.
///
/// Renvoie `null` si l'utilisateur annule, et la chaine vide s'il choisit
/// « aucune icone ».
Future<String?> showAppIconPicker(BuildContext context, String? current) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final entries = kAppIcons.entries.toList();
      return AlertDialog(
        title: const Text('Choisir une icône'),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: Scrollbar(
            thumbVisibility: true,
            child: GridView.builder(
              padding: const EdgeInsets.only(right: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = entry.key == current;
                return InkWell(
                  onTap: () => Navigator.pop(context, entry.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4E9F3D).withOpacity(0.15)
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF4E9F3D), width: 2)
                          : null,
                    ),
                    child: Tooltip(
                      message: entry.key,
                      child: Icon(
                        entry.value,
                        size: 26,
                        color: isSelected
                            ? const Color(0xFF4E9F3D)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Aucune icône'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      );
    },
  );
}
