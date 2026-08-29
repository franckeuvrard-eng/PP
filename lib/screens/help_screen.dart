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
              'Paramètres > Profil Classe : renseignez le nom de la classe, l\'enseignant et le niveau.',
              'Paramètres > Espaces & Ateliers : créez vos espaces (coin lecture, motricité...), puis un ou plusieurs ateliers dans chacun.',
              'Paramètres > Profil Classe > Sections : définissez vos sections (PS, MS, Groupe Rouge...).',
              'Élèves > Ajouter Élève : saisissez-les un par un, ou en une fois via Paramètres > Importer des élèves (Excel).',
              'Badges QR : imprimez les étiquettes des élèves et des ateliers.',
            ],
          ),
          _HelpSection(
            icon: Icons.qr_code_scanner,
            title: 'Scan & Go : enregistrer une observation',
            steps: [
              'Scannez le badge de l\'élève puis celui de l\'atelier, dans n\'importe quel ordre.',
              'Sans badge sous la main, utilisez la sélection manuelle.',
              'Choisissez le niveau d\'évaluation, ajoutez une note écrite ou vocale, et des photos si besoin.',
              'Chaque photo peut recevoir un commentaire, repris dans l\'export PDF.',
              'Saisie groupée : avant de valider, ajoutez d\'autres élèves via « Enregistrer aussi pour ». Une observation est créée pour chacun, avec la même note et les mêmes photos.',
              'Validez : l\'observation apparaît aussitôt dans le fil du jour.',
              'Une notification locale peut rappeler, à une heure choisie, les élèves pas encore observés dans la journée : Paramètres > Sauvegarde & Sécurité > Rappel élèves non évalués.',
            ],
          ),
          _HelpSection(
            icon: Icons.people,
            title: 'Fiche élève',
            steps: [
              'Onglet Profil : informations, photo et compteurs d\'observations.',
              'Onglet Activités : un atelier par ligne avec sa dernière observation ; toucher une ligne ouvre l\'historique complet de cet atelier pour l\'élève (toutes les occurrences, modifiables).',
              'Onglet Acquis, section Ateliers : « Voir le suivi des ateliers » détaille, atelier par atelier, ce qui est acquis, en cours ou pas encore fait.',
              'Onglet Acquis, section Analyse des sons : un appui fait progresser un son de non acquis (rouge) à en cours (jaune) puis acquis (vert). Appui long pour revenir en arrière. « Voir la progression dans le temps » affiche l\'évolution en graphique, radar ou tableau.',
              'Onglet Acquis, référentiels personnalisés : si vous en avez créé (ceintures de couleur, Montessori...), chacun apparaît en dessous des sons avec le même principe de suivi.',
              'Le crayon en haut à droite modifie la fiche, la corbeille supprime l\'élève.',
            ],
          ),
          _HelpSection(
            icon: Icons.stars,
            title: 'Ateliers obligatoires et progression',
            steps: [
              'Dans l\'édition d\'un atelier, activez « Atelier Obligatoire ».',
              'Sélectionnez ensuite les sections concernées. Si vous n\'en cochez aucune, l\'atelier est obligatoire pour toute la classe.',
              'Les statistiques et le rapport « Ateliers obligatoires » ne comptabilisent alors que les élèves des sections ciblées.',
              'Un espace peut en plus être mis en « Mode progression » (Paramètres > Espaces & Ateliers, en modifiant l\'espace) : ses ateliers doivent alors être faits dans l\'ordre, glissé-déposé pour réordonner, et un atelier reste verrouillé pour un élève tant que les précédents n\'ont pas atteint le statut minimum choisi.',
            ],
          ),
          _HelpSection(
            icon: Icons.checklist_rtl,
            title: 'Référentiels personnalisés',
            steps: [
              'Paramètres > Profil Classe > Référentiels personnalisés : créez vos propres suivis (ceintures de couleur, base Montessori...), avec vos groupes et vos items.',
              'Rien n\'est fourni par défaut : c\'est vous qui définissez le contenu, contrairement à l\'analyse des sons qui est intégrée à l\'application.',
              'Une fois créé, le référentiel apparaît automatiquement dans l\'onglet Acquis de chaque élève.',
            ],
          ),
          _HelpSection(
            icon: Icons.picture_as_pdf,
            title: 'Rapports et exports',
            steps: [
              'Onglet Rapports : point d\'entrée unique pour tous les documents.',
              'Ateliers obligatoires (PDF) : liste et statut, pour un ou plusieurs élèves choisis à la fois.',
              'Fiche atelier (PDF) : description, objectifs et photos légendées d\'un atelier.',
              'Export RGPD élève : toutes les données personnelles conservées pour un élève choisi.',
              'Bilan classe (Excel) : toutes les observations de la classe, au format tableur.',
              'Rapport PDF de la classe : historique détaillé de tous les élèves, avec choix de la période (tout, ce mois, cette semaine, ou personnalisée) et option pour ne garder que l\'occurrence la plus récente de chaque atelier.',
              'Rapport d\'un élève : aussi accessible depuis sa fiche (icône RGPD dans la barre du haut). L\'analyse des sons figure toujours en tête, quelle que soit la période.',
              'Dans un aperçu PDF, double-tapez une page pour l\'agrandir, puis pincez pour zoomer.',
            ],
          ),
          _HelpSection(
            icon: Icons.shield,
            title: 'Sécurité et sauvegarde',
            steps: [
              'Paramètres > Sauvegarde & Sécurité : activez ou non la demande de Face ID au démarrage. Le changement s\'applique au prochain lancement.',
              'Une sauvegarde automatique est créée chaque jour et les 5 dernières sont conservées : Paramètres > Sauvegarde & Sécurité > Voir et restaurer. Elle ne contient pas les photos.',
              'Sauvegardez régulièrement : le ZIP contient les données et les photos.',
              'La restauration remplace l\'intégralité des données existantes.',
              'En fin d\'année : « Passer à l\'année suivante » archive élèves et observations dans un ZIP daté, puis repart sur une classe vide en conservant espaces, ateliers, niveaux et sections. Les archives se retrouvent, se partagent ou se suppriment depuis le même écran.',
              'Réinitialisation sélective : au bas de l\'onglet Sauvegarde & Sécurité, pour effacer précisément certaines données (élèves, historique, ateliers...) plutôt que tout recommencer.',
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
              'Les niveaux d\'évaluation se modifient dans Paramètres > Profil Classe. Les renommer ne touche pas aux évaluations déjà enregistrées.',
              'Espaces et ateliers partagent les mêmes sélecteurs de couleur et d\'icône : leur apparence reste cohérente dans toute l\'application.',
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
            Text('A petits pas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
