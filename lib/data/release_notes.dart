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
