import 'package:flutter/material.dart';

/// Aide intégrée : rappel du fonctionnement écran par écran.
///
/// Volontairement hors ligne et sans lien externe : l'application est utilisée
/// en classe, souvent sans réseau.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Intro(),
          SizedBox(height: 8),
          _HelpSection(
            icon: Icons.rocket_launch,
            title: 'Pour bien démarrer',
            steps: [
              'Paramètres > Ma classe : renseignez le nom de la classe, l\'enseignant et le niveau.',
              'Paramètres > Espaces & Ateliers : créez vos espaces (coin lecture, motricité...), puis un ou plusieurs ateliers dans chacun.',
              'Paramètres > Ma classe > Sections : définissez vos sections (PS, MS, Groupe Rouge...).',
              'Élèves > Ajouter Élève : saisissez vos élèves en choisissant leur section.',
              'Badges QR : imprimez les étiquettes des élèves et des ateliers.',
            ],
          ),
          _HelpSection(
            icon: Icons.qr_code_scanner,
            title: 'Scan & Go : enregistrer une observation',
            steps: [
              'Scannez le badge de l\'élève puis celui de l\'atelier, dans n\'importe quel ordre.',
              'Sans badge sous la main, utilisez la sélection manuelle.',
              'Choisissez le niveau d\'évaluation, ajoutez une note et des photos si besoin.',
              'Chaque photo peut recevoir un commentaire, repris dans l\'export PDF.',
              'Saisie groupée : avant de valider, ajoutez d\'autres élèves via « Enregistrer aussi pour ». Une observation est créée pour chacun, avec la même note et les mêmes photos.',
              'Validez : l\'observation apparaît aussitôt dans le fil du jour.',
            ],
          ),
          _HelpSection(
            icon: Icons.people,
            title: 'Fiche élève',
            steps: [
              'Onglet Profil : informations, photo et compteurs d\'observations.',
              'Onglet Activités : historique complet, modifiable en touchant une ligne.',
              'Onglet Acquis : analyse des sons. Un appui fait progresser un son de non acquis (rouge) à en cours (jaune) puis acquis (vert). Appui long pour revenir en arrière.',
              'Le crayon en haut à droite modifie la fiche, la corbeille supprime l\'élève.',
            ],
          ),
          _HelpSection(
            icon: Icons.stars,
            title: 'Ateliers obligatoires',
            steps: [
              'Dans l\'édition d\'un atelier, activez « Atelier Obligatoire ».',
              'Sélectionnez ensuite les sections concernées. Si vous n\'en cochez aucune, l\'atelier est obligatoire pour toute la classe.',
              'Les statistiques ne comptabilisent alors que les élèves des sections ciblées.',
            ],
          ),
          _HelpSection(
            icon: Icons.picture_as_pdf,
            title: 'Exports',
            steps: [
              'Rapport d\'un élève : icône PDF depuis sa fiche, avec choix de la période. L\'analyse des sons figure toujours en tête, quelle que soit la période.',
              'Rapport de toute la classe : bouton en haut de l\'écran Élèves, un document unique avec une section par élève.',
              'Fiche d\'un atelier : icône PDF dans Paramètres > Espaces & Ateliers. Elle décrit l\'atelier et ses photos légendées.',
              'Tableur de la classe : bouton Excel depuis les Statistiques.',
              'Dans un aperçu PDF, double-tapez une page pour l\'agrandir, puis pincez pour zoomer.',
            ],
          ),
          _HelpSection(
            icon: Icons.shield,
            title: 'Sécurité et sauvegarde',
            steps: [
              'Paramètres > Sécurité : activez ou non la demande de Face ID au démarrage. Le changement s\'applique au prochain lancement.',
              'Une sauvegarde automatique est créée chaque jour et les 5 dernières sont conservées : Paramètres > Sécurité > Voir et restaurer. Elle ne contient pas les photos.',
              'Sauvegardez régulièrement : le ZIP contient les données et les photos.',
              'La restauration remplace l\'intégralité des données existantes.',
            ],
          ),
          _HelpSection(
            icon: Icons.lightbulb,
            title: 'Bon à savoir',
            steps: [
              'Les photos sont enregistrées dans l\'application, pas dans la pellicule.',
              'Après une suppression d\'élève ou d\'observation, « Annuler » reste proposé quelques secondes.',
              'Les photos qui ne sont plus rattachées à rien sont effacées automatiquement au démarrage.',
              'Supprimer un espace supprime les ateliers qu\'il contient.',
              'Les niveaux d\'évaluation sont modifiables dans les Paramètres.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PetitPas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              'Suivi des activités en maternelle : on scanne le badge d\'un élève '
              'et celui d\'un atelier, on note l\'observation, et l\'application '
              'construit l\'historique, les statistiques et les documents à '
              'remettre aux familles.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(icon, color: const Color(0xFF4E9F3D)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: steps
            .map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 8),
                        child: Icon(Icons.circle, size: 6, color: Color(0xFF4E9F3D)),
                      ),
                      Expanded(child: Text(step, style: const TextStyle(fontSize: 13, height: 1.35))),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
