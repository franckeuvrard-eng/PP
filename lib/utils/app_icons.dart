import 'package:flutter/material.dart';

/// Catalogue d'icones proposees pour les espaces, les ateliers et les
/// parcours, range par theme pour la grille de selection.
///
/// Les valeurs sont des constantes `Icons.*` et non des `IconData` construits
/// a partir d'un codePoint : Flutter elague les icones non referencees
/// litteralement au build (`--tree-shake-icons`), et une icone construite
/// dynamiquement s'afficherait alors comme un carre vide sur l'appareil.
///
/// Les cles sont enregistrees dans les donnees (ActivityType.iconName...) :
/// ne jamais renommer ni retirer une cle existante, seulement en ajouter.
const List<(String, Map<String, IconData>)> kAppIconGroups = [
  ('Arts et création', {
    'palette': Icons.palette,
    'brush': Icons.brush,
    'colorer': Icons.format_color_fill,
    'peinture': Icons.format_paint,
    'couleurs': Icons.color_lens,
    'dessin': Icons.draw,
    'trace': Icons.gesture,
    'ciseaux': Icons.content_cut,
    'collage': Icons.auto_awesome_mosaic,
    'photo': Icons.photo_camera,
    'galerie': Icons.collections,
    'theatre': Icons.theater_comedy,
    'masque': Icons.face,
    'fete': Icons.celebration,
    'magie': Icons.auto_fix_high,
  }),
  ('Musique et écoute', {
    'musique': Icons.music_note,
    'piano': Icons.piano,
    'chanson': Icons.queue_music,
    'son': Icons.audiotrack,
    'micro': Icons.mic,
    'casque': Icons.headphones,
    'ecoute': Icons.hearing,
    'volume': Icons.volume_up,
  }),
  ('Langage et lecture', {
    'livre': Icons.menu_book,
    'bibliotheque': Icons.local_library,
    'histoire': Icons.auto_stories,
    'album': Icons.import_contacts,
    'ecriture': Icons.edit,
    'crayon': Icons.create,
    'alphabet': Icons.abc,
    'lettres': Icons.text_fields,
    'mots': Icons.spellcheck,
    'discussion': Icons.record_voice_over,
    'bulle': Icons.chat_bubble,
    'echange': Icons.forum,
    'courrier': Icons.mail,
    'question': Icons.help_outline,
  }),
  ('Nombres et logique', {
    'calcul': Icons.calculate,
    'chiffres': Icons.pin,
    'un': Icons.looks_one,
    'deux': Icons.looks_two,
    'trois': Icons.looks_3,
    'des': Icons.casino,
    'formes': Icons.category,
    'carre': Icons.crop_square,
    'rond': Icons.circle_outlined,
    'triangle': Icons.change_history,
    'hexagone': Icons.hexagon_outlined,
    'puzzle': Icons.extension,
    'tri': Icons.sort,
    'balance': Icons.balance,
    'mesure': Icons.straighten,
    'equerre': Icons.square_foot,
    'quadrillage': Icons.grid_on,
    'suite': Icons.linear_scale,
    'algorithme': Icons.pattern,
    'graphique': Icons.pie_chart,
    'marchande': Icons.shopping_basket,
    'monnaie': Icons.payments,
  }),
  ('Temps', {
    'horloge': Icons.schedule,
    'minuteur': Icons.timer,
    'sablier': Icons.hourglass_bottom,
    'calendrier': Icons.calendar_month,
    'jour': Icons.light_mode,
    'nuit': Icons.nightlight,
  }),
  ('Motricité', {
    'course': Icons.directions_run,
    'marche': Icons.directions_walk,
    'randonnee': Icons.hiking,
    'velo': Icons.pedal_bike,
    'trottinette': Icons.electric_scooter,
    'roller': Icons.roller_skating,
    'ballon': Icons.sports_soccer,
    'basket': Icons.sports_basketball,
    'handball': Icons.sports_handball,
    'volley': Icons.sports_volleyball,
    'raquette': Icons.sports_tennis,
    'gymnastique': Icons.sports_gymnastics,
    'lutte': Icons.sports_kabaddi,
    'judo': Icons.sports_martial_arts,
    'piscine': Icons.pool,
    'equilibre': Icons.accessibility_new,
    'danse': Icons.emoji_people,
    'yoga': Icons.self_improvement,
    'main': Icons.back_hand,
    'motricite_fine': Icons.pan_tool_alt,
  }),
  ('Nature et vivant', {
    'nature': Icons.park,
    'foret': Icons.forest,
    'jardin': Icons.local_florist,
    'herbe': Icons.grass,
    'feuille': Icons.eco,
    'plante': Icons.spa,
    'graine': Icons.yard,
    'animaux': Icons.pets,
    'lapin': Icons.cruelty_free,
    'insecte': Icons.bug_report,
    'oeuf': Icons.egg,
    'corps': Icons.accessibility,
  }),
  ('Explorer le monde', {
    'science': Icons.science,
    'loupe': Icons.search,
    'observer': Icons.visibility,
    'idee': Icons.lightbulb,
    'eau': Icons.water_drop,
    'sable': Icons.beach_access,
    'meteo': Icons.wb_sunny,
    'nuage': Icons.cloud,
    'pluie': Icons.umbrella,
    'neige': Icons.ac_unit,
    'orage': Icons.thunderstorm,
    'monde': Icons.public,
    'carte': Icons.map,
    'boussole': Icons.explore,
    'espace_fusee': Icons.rocket_launch,
    'maison': Icons.home,
    'voiture': Icons.directions_car,
    'bus': Icons.directions_bus,
    'train': Icons.train,
    'avion': Icons.flight,
    'bateau': Icons.sailing,
  }),
  ('Construire et manipuler', {
    'construction': Icons.construction,
    'cubes': Icons.view_in_ar,
    'briques': Icons.view_module,
    'empiler': Icons.layers,
    'outils': Icons.handyman,
    'bricolage': Icons.build,
    'menuiserie': Icons.carpenter,
    'aimant': Icons.attractions,
    'jeu': Icons.toys,
    'jeu_societe': Icons.extension_outlined,
  }),
  ('Cuisine et goût', {
    'cuisine': Icons.restaurant,
    'recette': Icons.restaurant_menu,
    'gateau': Icons.cake,
    'boulangerie': Icons.bakery_dining,
    'glace': Icons.icecream,
    'fruits': Icons.local_grocery_store,
    'boisson': Icons.local_drink,
  }),
  ('Vivre ensemble', {
    'groupe': Icons.groups,
    'diversite': Icons.diversity_3,
    'entraide': Icons.handshake,
    'emotions': Icons.emoji_emotions,
    'humeur': Icons.mood,
    'partage': Icons.volunteer_activism,
    'famille': Icons.family_restroom,
    'bebe': Icons.child_care,
    'habillage': Icons.checkroom,
    'repos': Icons.bedtime,
    'hygiene': Icons.clean_hands,
    'savon': Icons.sanitizer,
    'regle': Icons.rule,
  }),
  ('Numérique', {
    'tablette': Icons.tablet_mac,
    'ordinateur': Icons.computer,
    'robot': Icons.smart_toy,
    'jeu_video': Icons.videogame_asset,
    'qr': Icons.qr_code,
  }),
  ('Repères et récompenses', {
    'etoile': Icons.star,
    'coeur': Icons.favorite,
    'trophee': Icons.emoji_events,
    'medaille': Icons.workspace_premium,
    'drapeau': Icons.flag,
    'cible': Icons.track_changes,
    'chemin': Icons.route,
    'escalier': Icons.stairs,
    'parcours': Icons.timeline,
    'espace': Icons.space_dashboard,
  }),
];

/// Toutes les icones du catalogue, par cle.
final Map<String, IconData> kAppIcons = {
  for (final (_, icons) in kAppIconGroups) ...icons,
};

/// Icone correspondant a [name], ou [fallback] si la cle est inconnue ou nulle.
IconData iconForName(String? name, {IconData fallback = Icons.category}) {
  if (name == null) return fallback;
  return kAppIcons[name] ?? fallback;
}

/// Ouvre une grille de selection, rangee par theme, et renvoie la cle choisie.
///
/// Renvoie `null` si l'utilisateur annule, et la chaine vide s'il choisit
/// « aucune icone ».
Future<String?> showAppIconPicker(BuildContext context, String? current) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      Widget tile(String key, IconData icon) {
        final isSelected = key == current;
        return InkWell(
          onTap: () => Navigator.pop(context, key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4E9F3D).withValues(alpha: 0.15)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFF4E9F3D), width: 2) : null,
            ),
            child: Tooltip(
              message: key,
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? const Color(0xFF4E9F3D) : scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      return AlertDialog(
        title: const Text('Choisir une icône'),
        content: SizedBox(
          width: double.maxFinite,
          height: 460,
          child: Scrollbar(
            thumbVisibility: true,
            child: CustomScrollView(
              slivers: [
                for (final (label, icons) in kAppIconGroups) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 12, 0, 6),
                      child: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(right: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 56,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      delegate: SliverChildListDelegate([
                        for (final e in icons.entries) tile(e.key, e.value),
                      ]),
                    ),
                  ),
                ],
              ],
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
