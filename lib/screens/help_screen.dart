import 'package:flutter/material.dart';

import '../data/release_notes.dart';
import 'onboarding_screen.dart';
import 'whats_new_screen.dart';

/// Aide intégrée : rappel du fonctionnement écran par écran.
///
/// Volontairement hors ligne et sans lien externe : l'application est utilisée
/// en classe, souvent sans réseau.
/// Prise en main et nouveautes, en tete de l'Aide. Une etape choisie dans la
/// liste de parametrage referme l'Aide en la renvoyant a l'ecran principal.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.school, color: Color(0xFF4E9F3D)),
            title: const Text('Prise en main', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Visite des écrans et paramétrage de la classe, pas à pas.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final target = await Navigator.push<SetupTarget>(
                context,
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => const OnboardingScreen()),
              );
              if (target != null && context.mounted) Navigator.pop(context, target);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.new_releases, color: Color(0xFF4E9F3D)),
            title: const Text('Nouveautés', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Ce qui a changé dans la version ${kReleaseNotes.first.version}.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const WhatsNewScreen())),
          ),
        ],
      ),
    );
  }
}

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
          _QuickLinks(),
          SizedBox(height: 8),
          _Intro(),
          SizedBox(height: 8),
          _HelpSection(
            icon: Icons.rocket_launch,
            title: 'Pour bien démarrer',
            steps: [
              'Paramètres > Profil Classe : renseignez le nom de la classe, l\'enseignant et le niveau.',
              'Espaces & Ateliers (menu principal) : créez vos espaces (coin lecture, motricité...), puis un ou plusieurs ateliers dans chacun.',
              'Paramètres > Profil Classe > Sections : définissez vos sections (PS, MS, Groupe Rouge...).',
              'Élèves > Ajouter Élève : saisissez-les un par un, ou en une fois via Paramètres > Importer des élèves (Excel).',
              'QR codes (Rapports > QR codes sur iPhone, Badges QR dans la barre latérale sur Mac et iPad) : badges des élèves et étiquettes des ateliers, une ou plusieurs pages par domaine. Les QR des étapes s\'impriment depuis Parcours, une ou plusieurs pages par parcours.',
            ],
          ),
          _HelpSection(
            icon: Icons.qr_code_scanner,
            title: 'Scan & Go : enregistrer une observation',
            steps: [
              'Choisissez d\'abord le mode : « Scanner les QR codes » ou « Sélection manuelle ». Après chaque enregistrement, on enchaîne avec l\'élève suivant (la caméra se rouvre en mode QR).',
              'Mode QR : scannez le badge de l\'élève et l\'étiquette de l\'atelier ou de l\'étape, dans n\'importe quel ordre.',
              'Mode manuel : tapez quelques lettres du prénom ou du nom de l\'élève, puis choisissez l\'atelier rangé par domaine et sous-domaine, ou l\'étape rangée par parcours. La recherche trouve aussi un domaine ou un parcours.',
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
            title: 'Plan de travail',
            steps: [
              'Dans l\'édition d\'un atelier, activez « Plan de travail ».',
              'Sélectionnez ensuite les sections concernées. Si vous n\'en cochez aucune, l\'atelier est dans le plan de travail de toute la classe.',
              'Les statistiques et le rapport « Plan de travail » ne comptabilisent alors que les élèves des sections ciblées.',
            ],
          ),
          _HelpSection(
            icon: Icons.timeline,
            title: 'Parcours',
            steps: [
              'Un parcours est une suite d\'étapes à faire dans l\'ordre (par exemple : couper une bande, puis une ligne droite, puis une courbe). Ce n\'est pas un atelier : il n\'est rangé dans aucun espace.',
              'Créez-le dans Parcours > onglet Gérer, choisissez le seuil de passage, les sections qui le suivent, puis ajoutez ses étapes avec « Ajouter une étape ». Glissez la poignée ⠿ pour changer leur ordre.',
              'Sections : sans section cochée, toute la classe suit le parcours. Sinon seuls les élèves de ces sections apparaissent dans le suivi, le plan de travail et le rapport des parcours.',
              'Une étape reste verrouillée pour un élève tant que la précédente n\'a pas atteint le seuil de passage.',
              'L\'écran Parcours (barre latérale sur Mac et iPad, onglet Ateliers sur iPhone) montre le fil : où en est la classe, ou un élève. L\'onglet Parcours de la fiche élève montre la même chose pour lui.',
              'Frise : le bouton frise de l\'écran Parcours (ou Rapports > Frise d\'un parcours) imprime le parcours en grand, trois étapes par page à mettre bout à bout, vierge pour les pinces des élèves ou avec leurs prénoms.',
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
              'Plan de travail (PDF) : les ateliers du plan de travail en vignettes, en paysage, pour un ou plusieurs élèves. Avant l\'export, choisissez d\'afficher ou non le statut et les cases à cocher, et quels statuts inclure (par exemple seulement « Jamais fait »).',
              'Parcours des élèves (PDF) : le même principe pour les étapes des parcours, avec en plus le choix des parcours.',
              'Suivi des parcours (PDF ou Excel) : tableau croisé élèves × parcours, avec l\'étape où en est chacun. Le fichier Excel contient aussi une feuille « Données » prête pour un tableau croisé dynamique.',
              'Fiche atelier ou parcours (PDF) : description, objectifs et photos légendées d\'un atelier, ou d\'un parcours avec toutes ses étapes dans l\'ordre.',
              'RGPD : l\'export des données d\'un élève, son effacement, la politique de confidentialité, l\'archivage de fin d\'année et la réinitialisation sont regroupés dans Paramètres > RGPD.',
              'Bilan classe (Excel) : toutes les observations de la classe, au format tableur.',
              'Rapport des élèves (PDF) : pour un élève, plusieurs ou toute la classe. Choisissez la période (tout, ce mois, cette semaine, ou personnalisée), si l\'analyse des sons et vos référentiels apparaissent, et si les activités sont regroupées par domaine et sous-domaine, puis par parcours (sinon par date). Option pour ne garder que l\'occurrence la plus récente de chaque atelier.',
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
              'Réinitialisation sélective : dans Paramètres > RGPD, pour effacer précisément certaines données (élèves, historique, ateliers...) plutôt que tout recommencer.',
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
