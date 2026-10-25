import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/seed_ids.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';

const _green = Color(0xFF4E9F3D);

/// Ou emmener l'utilisateur depuis la liste de parametrage (traite par
/// l'ecran principal, qui connait les onglets).
enum SetupTarget { classProfile, spaces, students, importStudents, badges, security }

/// Prise en main : presentation des ecrans principaux, puis liste de
/// parametrage qui se coche selon ce qui est reellement fait.
///
/// Affichee au premier lancement et depuis l'Aide. Renvoie (Navigator.pop)
/// la [SetupTarget] choisie, ou null.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.startOnChecklist = false});

  /// Ouvrir directement la liste de parametrage.
  final bool startOnChecklist;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _TourPage {
  const _TourPage(this.icon, this.title, this.subtitle, this.points);
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;
}

const _tour = [
  _TourPage(Icons.waving_hand, 'Bienvenue dans A petits pas',
      'Le suivi des élèves de maternelle, simplement, en classe.', [
    'Notez une observation en quelques secondes, avec un QR code.',
    'Suivez les progrès de chaque élève, atelier par atelier.',
    'Partagez des bilans PDF et Excel avec les familles et l\'équipe.',
    'Vos données restent sur vos appareils et dans votre iCloud.',
  ]),
  _TourPage(Icons.home, 'Accueil', 'Votre journée en un coup d\'œil.', [
    'Le fil du jour liste les observations saisies aujourd\'hui ; touchez le crayon pour en modifier une.',
    '« Aujourd\'hui » compte les observations du jour, « Analyses » ouvre les statistiques.',
    'Sur iPhone, l\'onglet Ateliers ouvre Espaces & Ateliers et Parcours ; le menu « ⋯ » en haut ouvre Badges QR, Rapports et l\'Aide. Sur Mac et iPad, tout est dans la barre latérale.',
    '« Rapports » regroupe le plan de travail, le suivi des parcours, les fiches PDF et les exports.',
    'Tirez vers le bas pour synchroniser avec vos autres appareils.',
  ]),
  _TourPage(Icons.qr_code_2, 'Scan & Go', 'Enregistrer une observation.', [
    'Choisissez le mode : scanner les QR codes, ou sélection manuelle.',
    'En manuel, tapez quelques lettres du nom de l\'élève, puis choisissez l\'atelier par domaine ou l\'étape par parcours.',
    'Indiquez le niveau (non acquis, en cours, acquis…), ajoutez une note écrite ou vocale et des photos.',
    '« Enregistrer aussi pour » crée la même observation pour plusieurs élèves.',
  ]),
  _TourPage(Icons.people, 'Élèves', 'Les fiches de la classe.', [
    'Chaque fiche regroupe le profil, l\'historique des activités et les acquis.',
    'Les filtres montrent qui attend encore une observation aujourd\'hui.',
    'L\'icône PDF produit la fiche d\'un élève à partager avec sa famille.',
    'Ajoutez les élèves un par un, ou tous d\'un coup depuis un fichier Excel.',
  ]),
  _TourPage(Icons.print, 'Badges QR', 'Les étiquettes à imprimer.', [
    'Un badge par élève, une étiquette par atelier, rangées par domaine. Les QR des étapes sont dans Parcours.',
    '« Exporter PDF » prépare une planche prête à imprimer et à plastifier.',
    'Réimprimez un badge à tout moment, il reste valable.',
  ]),
  _TourPage(Icons.tune, 'Paramètres', 'Votre classe, à votre façon.', [
    'Profil Classe : nom, enseignant, ATSEM, niveau, sections, logo.',
    'Parcours : des ateliers à faire dans l\'ordre, comme un chemin avec ses étapes.',
    'Apparence : mode clair ou sombre.',
    'Sauvegarde & Sécurité : Face ID, sauvegardes, synchronisation entre appareils.',
  ]),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.startOnChecklist ? _tour.length : 0);
  late int _index = widget.startOnChecklist ? _tour.length : 0;

  int get _count => _tour.length + 1; // + liste de parametrage

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final last = _index == _count - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prise en main'),
        actions: [
          if (!last)
            TextButton(
              onPressed: () => _pages.animateToPage(_count - 1,
                  duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic),
              child: const Text('Passer'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                for (final page in _tour) _TourView(page: page),
                const _SetupChecklist(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? _green : _green.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FilledButton(
            onPressed: last ? () => Navigator.pop(context) : _next,
            child: Text(last ? 'Terminer' : 'Suivant'),
          ),
        ),
      ),
    );
  }
}

class _TourView extends StatelessWidget {
  const _TourView({required this.page});
  final _TourPage page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _green.withValues(alpha: 0.12),
                child: Icon(page.icon, size: 40, color: _green),
              ),
            ),
            const SizedBox(height: 18),
            Text(page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(page.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: kMutedTextColor)),
            const SizedBox(height: 22),
            for (final p in page.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle, size: 18, color: _green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: const TextStyle(fontSize: 15, height: 1.35))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Etapes de parametrage, cochees d'apres l'etat reel de la classe.
class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final settings = app.classSettings;
    final profileDone = settings.teacher.trim().isNotEmpty &&
        settings.teacher != 'Mme Dupont' &&
        settings.name != 'Classe Petite Section (PS)';
    final ownChildren = app.children.where((c) => !kSeedChildIds.contains(c.id)).length;
    final seedChildren = app.children.where((c) => kSeedChildIds.contains(c.id)).length;

    void go(SetupTarget t) => Navigator.pop(context, t);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Paramétrez votre classe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Quelques minutes suffisent. Chaque étape se coche toute seule une fois faite ; '
              'vous pouvez y revenir depuis Aide › Prise en main.',
              style: TextStyle(fontSize: 14, color: kMutedTextColor),
            ),
            const SizedBox(height: 16),
            _Step(
              done: profileDone,
              title: '1. Le profil de la classe',
              text: 'Nom de la classe, enseignant(e), ATSEM, niveau et sections (PS, MS, groupes…).',
              action: 'Ouvrir Profil Classe',
              onTap: () => go(SetupTarget.classProfile),
            ),
            _Step(
              done: app.activityTypes.isNotEmpty,
              title: '2. Vos espaces et ateliers',
              text: app.activityTypes.isEmpty
                  ? 'Créez vos coins de classe puis les ateliers de chacun.'
                  : '${app.spaces.length} espace(s), ${app.activityTypes.length} atelier(s). '
                      'Des exemples sont fournis : adaptez-les à votre classe.',
              action: 'Ouvrir Espaces & Ateliers',
              onTap: () => go(SetupTarget.spaces),
            ),
            _Step(
              done: ownChildren > 0,
              title: '3. Vos élèves',
              text: ownChildren > 0
                  ? '$ownChildren élève(s) dans la classe.'
                  : 'Ajoutez-les un par un, ou tous d\'un coup depuis un modèle Excel.',
              action: 'Ajouter des élèves',
              onTap: () => go(SetupTarget.students),
              secondaryAction: 'Importer depuis Excel',
              onSecondary: () => go(SetupTarget.importStudents),
              extra: seedChildren > 0
                  ? TextButton.icon(
                      onPressed: () {
                        for (final id in kSeedChildIds) {
                          if (app.children.any((c) => c.id == id)) app.deleteChild(id);
                        }
                      },
                      icon: const Icon(Icons.cleaning_services, size: 18),
                      label: Text('Retirer les $seedChildren élèves d\'exemple'),
                    )
                  : null,
            ),
            _Step(
              done: false,
              optional: true,
              title: '4. Les badges QR',
              text: 'Imprimez les badges des élèves et les étiquettes des ateliers pour Scan & Go.',
              action: 'Ouvrir Badges QR',
              onTap: () => go(SetupTarget.badges),
            ),
            _Step(
              done: app.biometricLockEnabled && app.iCloudSyncEnabled,
              optional: true,
              title: '5. Sécurité et synchronisation',
              text: 'Verrouillage Face ID / code, sauvegardes, synchronisation avec vos autres '
                  'appareils (iCloud ou Wi-Fi).',
              action: 'Ouvrir Sauvegarde & Sécurité',
              onTap: () => go(SetupTarget.security),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
    this.optional = false,
    this.secondaryAction,
    this.onSecondary,
    this.extra,
  });

  final bool done;
  final bool optional;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;
  final String? secondaryAction;
  final VoidCallback? onSecondary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? _green : kMutedTextColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    if (optional && !done)
                      const Text('conseillé',
                          style: TextStyle(fontSize: 11, color: kMutedTextColor)),
                  ]),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: onTap, child: Text(action)),
                    if (secondaryAction != null)
                      OutlinedButton(onPressed: onSecondary, child: Text(secondaryAction!)),
                  ]),
                  if (extra != null) extra!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
