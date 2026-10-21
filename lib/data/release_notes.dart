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
