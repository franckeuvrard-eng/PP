import 'package:flutter/material.dart';

/// Nouveautes affichees une fois apres chaque mise a jour, puis dans l'Aide.
///
/// La premiere entree doit porter la version de pubspec.yaml (verifie par
/// test/release_notes_test.dart) : ajouter une entree a chaque version publiee,
/// redigee pour les enseignants, sans jargon technique.
class ReleaseNote {
  const ReleaseNote({required this.version, required this.date, required this.items});

  final String version;
  final String date;
  final List<ReleaseItem> items;
}

class ReleaseItem {
  const ReleaseItem(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

const kReleaseNotes = [
  ReleaseNote(
    version: '1.6.3',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.grid_view, 'Le plan de travail en vignettes',
          'Chaque atelier est une vignette avec toutes ses photos, son nom, son statut et trois '
              'cases que l\'élève coche à chaque passage. La bordure devient verte une fois acquis.'),
      ReleaseItem(Icons.subdirectory_arrow_right, 'Le sous-domaine est enregistré',
          'Le sous-domaine choisi sur un atelier ou une étape est gardé et affiché sur sa fiche. '
              'Rouvrez vos ateliers existants pour le choisir.'),
      ReleaseItem(Icons.photo_library, 'Toutes les photos',
          'Les vignettes du plan de travail et la frise des parcours montrent toutes les photos '
              'd\'un atelier, en entier.'),
      ReleaseItem(Icons.system_update, 'Mettez à jour tous vos appareils',
          'La synchronisation par Wi-Fi ne se fait qu\'entre appareils en version 1.6.3.'),
    ],
  ),
  ReleaseNote(
    version: '1.6.2',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.content_paste, 'Coller une image',
          'Copiez une image sur un site (appui long sur iPhone, clic droit sur Mac), puis touchez '
              '« Coller » dans les photos d\'un atelier ou d\'une étape. Elle est ajoutée comme une '
              'photo, et peut recevoir une légende.'),
    ],
  ),
  ReleaseNote(
    version: '1.6.1',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.qr_code_scanner, 'Scan & Go en deux modes',
          'Choisissez d\'abord : scanner les QR codes, ou sélection manuelle. Après chaque '
              'observation, on enchaîne avec l\'élève suivant (la caméra se rouvre en mode QR).'),
      ReleaseItem(Icons.search, 'Retrouver vite un élève et un atelier',
          'En manuel, tapez quelques lettres du prénom ou du nom. Les ateliers sont rangés par '
              'domaine et sous-domaine, les étapes par parcours, et la recherche les trouve tous.'),
      ReleaseItem(Icons.qr_code_2, 'Les QR codes bien rangés',
          'Les étiquettes des ateliers s\'impriment par domaine, celles des étapes depuis '
              'Parcours, une ou plusieurs pages par parcours.'),
      ReleaseItem(Icons.space_dashboard, 'Une navigation plus simple',
          'Sur iPhone, l\'onglet Ateliers ouvre Espaces & Ateliers et Parcours ; le menu « ⋯ » '
              'en haut ouvre Badges QR, Rapports et l\'Aide. Sur Mac et iPad, tout est dans la '
              'barre latérale. Les parcours se gèrent depuis leur page, onglet Gérer.'),
    ],
  ),
  ReleaseNote(
    version: '1.6.0',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.school, 'Le programme de maternelle à jour',
          'Les domaines et objectifs suivent le programme en vigueur (BO du 31 octobre 2024 et '
              'du 7 mai 2026). On choisit le cycle, le domaine, puis le sous-domaine ; chaque '
              'objectif affiche son âge (avant 4 ans, dès 4 ans, dès 5 ans). Vos ateliers gardent '
              'leurs objectifs et domaines actuels.'),
      ReleaseItem(Icons.timeline, 'Des parcours et leurs étapes',
          'Les progressions s\'appellent maintenant des parcours. Un parcours n\'est pas un '
              'atelier : ses étapes se créent depuis le parcours, et vous choisissez les sections '
              'qui le suivent.'),
      ReleaseItem(Icons.view_carousel, 'La frise à afficher en classe',
          'Imprimez un parcours en grand, étape par étape, pour que les élèves suivent eux-mêmes '
              'où ils en sont : vierge pour leurs pinces, ou avec leurs prénoms.'),
      ReleaseItem(Icons.grid_on, 'Suivi des parcours',
          'Un tableau élèves × parcours montre l\'étape où en est chacun, en PDF ou en Excel '
              '(avec une feuille prête pour un tableau croisé dynamique).'),
      ReleaseItem(Icons.assignment_turned_in, 'Le plan de travail',
          'Les « ateliers obligatoires » deviennent le plan de travail. Son PDF montre les '
              'photos des ateliers, et les parcours sur une page à part.'),
      ReleaseItem(Icons.visibility_off, 'Mettre un atelier de côté',
          'Désactivez un atelier depuis sa fiche : il disparaît d\'Espaces & Ateliers mais '
              'reste dans les observations, les rapports et les statistiques.'),
      ReleaseItem(Icons.space_dashboard, 'Plus près de vous',
          'Espaces & Ateliers et Rapports ont leur place dans le menu (barre latérale sur Mac '
              'et iPad ; accueil et barre du haut sur iPhone). Et beaucoup plus d\'icônes pour vos '
              'ateliers.'),
      ReleaseItem(Icons.system_update, 'Mettez à jour tous vos appareils',
          'La synchronisation par Wi-Fi ne se fait qu\'entre appareils en version 1.6.'),
    ],
  ),
  ReleaseNote(
    version: '1.5.0',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.timeline, 'Les progressions ont leur place',
          'Les progressions ne sont plus un mode des espaces : elles ont leur propre onglet dans '
              'Paramètres. Une progression est une suite d\'ateliers (ses jalons) à faire dans '
              'l\'ordre. Un atelier est rangé soit dans un espace, soit dans une progression.'),
      ReleaseItem(Icons.route, 'Le fil de la progression',
          'Le nouvel écran Progressions montre le chemin et ses jalons : combien d\'élèves ont '
              'validé chaque étape et qui en est où, ou, pour un élève, ce qu\'il a validé, où il '
              'est, et ce qui reste verrouillé. Aussi dans la fiche élève.'),
      ReleaseItem(Icons.auto_fix_high, 'Rien à refaire',
          'Vos espaces en « mode progression » sont devenus des progressions, avec leurs ateliers, '
              'leur ordre, leur seuil et toutes les observations. Une sauvegarde est faite avant.'),
      ReleaseItem(Icons.system_update, 'Mettez à jour tous vos appareils',
          'La synchronisation (iCloud ou Wi-Fi) ne se fait qu\'entre appareils en version 1.5.'),
    ],
  ),
  ReleaseNote(
    version: '1.4.1',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.alternate_email, 'Deux emails de parents',
          'Chaque fiche élève accepte un second email (l\'autre parent, un tuteur). Les deux '
              'sont proposés lors du partage d\'un bilan, et le modèle d\'import Excel a une '
              'colonne « Email parent 2 ».'),
      ReleaseItem(Icons.photo, 'Photos entières',
          'Les vignettes montrent la photo en entier, sans la recadrer ; touchez-la pour '
              'l\'afficher en grand et zoomer. Les PDF gardent aussi les photos entières.'),
      ReleaseItem(Icons.sync_problem, 'Synchronisation : vous êtes prévenu',
          'Si la synchronisation doit supprimer beaucoup d\'éléments ou vous demander un choix, '
              'une fenêtre l\'annonce tout de suite, au lieu d\'attendre sans rien dire.'),
      ReleaseItem(Icons.star_half, 'Ateliers obligatoires',
          'Un atelier obligatoire pour une section reste accessible aux autres sections, '
              'où il est simplement facultatif.'),
      ReleaseItem(Icons.swap_vert, 'Ordre des ateliers plus clair',
          'Dans un espace en progression, chaque atelier affiche son rang ; glissez la poignée '
              'verte ⠿ pour changer l\'ordre.'),
      ReleaseItem(Icons.link_off, 'Observations orphelines',
          'Supprimer un atelier supprime aussi ses observations. Les anciennes observations '
              'sans élève ou sans atelier se nettoient dans Sauvegarde & Sécurité.'),
      ReleaseItem(Icons.view_sidebar, 'Panneau repliable sur Mac',
          'Repliez le panneau de gauche pour gagner de la place (bouton en haut du panneau, '
              'ou Ctrl+Cmd+S).'),
      ReleaseItem(Icons.notifications_off, 'Bandeaux plus discrets',
          'Les bandeaux « Annuler » disparaissent seuls et ne cachent plus les boutons.'),
      ReleaseItem(Icons.laptop_mac, 'Icône sur Mac',
          'L\'application porte la même icône que sur iPhone et iPad.'),
    ],
  ),
  ReleaseNote(
    version: '1.4.0',
    date: 'Octobre 2026',
    items: [
      ReleaseItem(Icons.cloud_sync, 'Synchronisation iCloud automatique',
          'iPhone, iPad et Mac se mettent à jour tout seuls, en quelques secondes, avec votre '
              'compte iCloud. Tirez vers le bas sur l\'accueil (Cmd+R sur Mac) pour synchroniser '
              'tout de suite.'),
      ReleaseItem(Icons.fact_check, 'Vous gardez la main',
          'Rien n\'est supprimé sans votre accord : un aperçu montre ce qui va changer sur chaque '
              'appareil. Si un même élément a été modifié des deux côtés, vous choisissez quoi '
              'garder, champ par champ.'),
      ReleaseItem(Icons.wifi, 'Synchronisation Wi-Fi avec un PC',
          'Les appareils se trouvent tout seuls sur le Wi-Fi de l\'école. L\'appareil qui reçoit '
              'doit accepter la demande.'),
      ReleaseItem(Icons.restore_from_trash, 'Photos protégées',
          'Une photo supprimée reste 60 jours dans une corbeille, et une sauvegarde est faite '
              'avant chaque synchronisation.'),
      ReleaseItem(Icons.save_alt, 'Exports sur Mac et PC',
          'Le modèle d\'import, les sauvegardes et les archives s\'enregistrent avec une fenêtre '
              '« Enregistrer sous ».'),
      ReleaseItem(Icons.school, 'Prise en main',
          'Une visite guidée présente chaque écran et vous accompagne pour paramétrer votre '
              'classe (Aide › Prise en main).'),
    ],
  ),
];
