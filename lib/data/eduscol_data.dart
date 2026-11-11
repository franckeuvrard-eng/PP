// GENERE a partir du programme officiel : ne pas modifier a la main.
//
// Source : « Programme d'enseignement - École maternelle », Éduscol,
// d'après le BO n° 41 du 31 octobre 2024 et le BO n° 19 du 7 mai 2026
// (eduscol.education.gouv.fr, programme-cycle-1-consolide).
//
// Les identifiants de domaine sont enregistres sur les ateliers : ne jamais
// en renommer ni en retirer. Un domaine qui n'existe plus reste ici avec
// `legacy: true` (il s'affiche encore, mais n'est plus propose). Les
// objectifs, eux, sont enregistres par leur texte : un ancien objectif
// reste lisible sur l'atelier meme s'il a disparu du referentiel.

class EduscolDomain {
  final String id;
  final String title;
  final String iconName;
  final String colorHex;

  /// Cycle du programme (1 : maternelle).
  final int cycle;

  /// Domaine d'un ancien programme : reconnu, plus propose.
  final bool legacy;

  /// Anciens intitules du meme domaine, pour reconnaitre les ateliers
  /// enregistres avec eux.
  final List<String> legacyTitles;

  const EduscolDomain({
    required this.id,
    required this.title,
    required this.iconName,
    required this.colorHex,
    this.cycle = 1,
    this.legacy = false,
    this.legacyTitles = const [],
  });

  bool matchesTitle(String t) => title == t || legacyTitles.contains(t);
}

/// Sous-domaine d'un domaine (ex. « Découvrir le monde de la matière et des
/// objets »).
class EduscolSubdomain {
  final String id;
  final String domainId;
  final String title;

  const EduscolSubdomain({required this.id, required this.domainId, required this.title});
}

class EduscolObjective {
  final String id;
  final String domainId;
  final String subdomainId;

  /// Theme du sous-domaine (ex. « Découvrir les objets et les matériaux »),
  /// ou null quand le programme n'en donne pas.
  final String? theme;

  /// 'PS' (à aborder avant 4 ans), 'MS' (à partir de 4 ans), 'GS' (à
  /// partir de 5 ans) : voir [EduscolData.ageLabel].
  final String level;
  final String text;

  const EduscolObjective({
    required this.id,
    required this.domainId,
    required this.subdomainId,
    this.theme,
    required this.level,
    required this.text,
  });
}

class EduscolData {
  /// Cycles disponibles. Le cycle 2 viendra s'ajouter ici.
  static const List<int> cycles = [1];

  /// Niveaux de chaque cycle, dans l'ordre.
  static const Map<int, List<String>> levels = {1: ['PS', 'MS', 'GS']};

  /// Tranche d'age donnee par le programme pour un niveau.
  static String? ageLabel(String level) => const {
        'PS': 'Avant 4 ans',
        'MS': 'Dès 4 ans',
        'GS': 'Dès 5 ans',
      }[level];

  static String cycleLabel(int cycle) => const {
        1: 'Cycle 1 · Maternelle',
        2: 'Cycle 2 · CP-CE2',
      }[cycle] ?? 'Cycle $cycle';

  /// Niveaux ou figure un objectif de ce texte (un meme intitule peut
  /// revenir d'une tranche d'age a l'autre). Vide pour un objectif
  /// personnalise ou d'un ancien programme.
  static List<String> levelsForText(String text) => [
        for (final o in objectives)
          if (o.text == text) o.level,
      ];

  static EduscolDomain? domainById(String? id) {
    for (final d in domains) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Domaine dont l'intitule (actuel ou ancien) est [title].
  static EduscolDomain? domainByTitle(String title) {
    for (final d in domains) {
      if (d.matchesTitle(title)) return d;
    }
    return null;
  }

  /// Domaines proposes pour un cycle (sans les anciens).
  static List<EduscolDomain> domainsForCycle(int cycle) =>
      [for (final d in domains) if (d.cycle == cycle && !d.legacy) d];

  static List<EduscolSubdomain> subdomainsOf(String domainId) =>
      [for (final s in subdomains) if (s.domainId == domainId) s];

  static EduscolSubdomain? subdomainById(String? id) {
    for (final s in subdomains) {
      if (s.id == id) return s;
    }
    return null;
  }

  static const List<EduscolDomain> domains = [
    EduscolDomain(
      id: 'd1_langage',
      title: 'Le développement et la structuration du langage oral et écrit',
      iconName: 'record_voice_over',
      colorHex: '#FF7043',
      legacyTitles: ['Mobiliser le langage dans toutes ses dimensions'],
    ),
    EduscolDomain(
      id: 'd3_physique',
      title: 'Agir, s\'exprimer, comprendre à travers les activités physiques',
      iconName: 'directions_run',
      colorHex: '#7E57C2',
      legacyTitles: ['Agir, s\'exprimer, comprendre à travers l\'activité physique'],
    ),
    EduscolDomain(
      id: 'd4_art',
      title: 'Agir, s\'exprimer, comprendre à travers les activités artistiques',
      iconName: 'palette',
      colorHex: '#E91E63',
    ),
    EduscolDomain(
      id: 'd2_maths',
      title: 'L\'acquisition des premiers outils mathématiques',
      iconName: 'calculate',
      colorHex: '#4E9F3D',
      legacyTitles: ['Acquérir les premiers outils mathématiques'],
    ),
    EduscolDomain(
      id: 'd5_temps_espace',
      title: 'Se repérer dans le temps et l\'espace',
      iconName: 'schedule',
      colorHex: '#FFA726',
    ),
    EduscolDomain(
      id: 'd6_vivant_matiere',
      title: 'Découvrir le monde du vivant, de la matière et des objets',
      iconName: 'public',
      colorHex: '#00BCD4',
    ),
    // Ancien programme (2015-2021) : divise depuis en « Se repérer dans le
    // temps et l'espace » et « Découvrir le monde du vivant, de la matière
    // et des objets ».
    EduscolDomain(
      id: 'd5_monde',
      title: 'Explorer le monde',
      iconName: 'public',
      colorHex: '#26A69A',
      legacy: true,
    ),
  ];

  static const List<EduscolSubdomain> subdomains = [
    EduscolSubdomain(id: 'c1_l1', domainId: 'd1_langage', title: 'Acquérir le langage oral'),
    EduscolSubdomain(id: 'c1_l2', domainId: 'd1_langage', title: 'Passer de l\'oral à l\'écrit : se préparer à apprendre à lire'),
    EduscolSubdomain(id: 'c1_l3', domainId: 'd1_langage', title: 'Passer de l\'oral à l\'écrit : se préparer à apprendre à écrire'),
    EduscolSubdomain(id: 'c1_p1', domainId: 'd3_physique', title: 'Se déplacer'),
    EduscolSubdomain(id: 'c1_p2', domainId: 'd3_physique', title: 'Construire des équilibres'),
    EduscolSubdomain(id: 'c1_p3', domainId: 'd3_physique', title: 'S\'exprimer avec son corps'),
    EduscolSubdomain(id: 'c1_p4', domainId: 'd3_physique', title: 'Coopérer et s\'opposer'),
    EduscolSubdomain(id: 'c1_a1', domainId: 'd4_art', title: 'Arts visuels'),
    EduscolSubdomain(id: 'c1_a2', domainId: 'd4_art', title: 'Les univers sonores'),
    EduscolSubdomain(id: 'c1_a3', domainId: 'd4_art', title: 'Le spectacle vivant'),
    EduscolSubdomain(id: 'c1_m1', domainId: 'd2_maths', title: 'Découvrir les nombres'),
    EduscolSubdomain(id: 'c1_m2', domainId: 'd2_maths', title: 'Utiliser les nombres pour résoudre des problèmes'),
    EduscolSubdomain(id: 'c1_m3', domainId: 'd2_maths', title: 'Explorer les solides et les formes planes'),
    EduscolSubdomain(id: 'c1_m4', domainId: 'd2_maths', title: 'Explorer des grandeurs : la longueur, la masse'),
    EduscolSubdomain(id: 'c1_m5', domainId: 'd2_maths', title: 'Se familiariser avec les motifs organisés'),
    EduscolSubdomain(id: 'c1_t1', domainId: 'd5_temps_espace', title: 'Se repérer dans le temps'),
    EduscolSubdomain(id: 'c1_t2', domainId: 'd5_temps_espace', title: 'Se repérer dans l\'espace'),
    EduscolSubdomain(id: 'c1_v1', domainId: 'd6_vivant_matiere', title: 'Découvrir le monde du vivant'),
    EduscolSubdomain(id: 'c1_v2', domainId: 'd6_vivant_matiere', title: 'Découvrir le monde de la matière et des objets'),
  ];

  static const List<EduscolObjective> objectives = [
    // Acquérir le langage oral
    EduscolObjective(id: 'c1_l1_ps1', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'PS', text: 'Comprendre, mémoriser, réemployer les mots des corpus enseignés (2 par période)'),
    EduscolObjective(id: 'c1_l1_ps2', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'PS', text: 'Organiser les mots en catégorie et en réseau'),
    EduscolObjective(id: 'c1_l1_ms1', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'MS', text: 'Comprendre, mémoriser, réemployer les mots des corpus enseignés (2 par période)'),
    EduscolObjective(id: 'c1_l1_ms2', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'MS', text: 'Organiser les mots en catégorie et en réseau'),
    EduscolObjective(id: 'c1_l1_gs1', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'GS', text: 'Comprendre, mémoriser, réemployer les mots des corpus enseignés (3 par période)'),
    EduscolObjective(id: 'c1_l1_gs2', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Enrichir son vocabulaire', level: 'GS', text: 'Organiser les mots en catégorie et en réseau'),
    EduscolObjective(id: 'c1_l1_ps3', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'PS', text: 'Diversifier les pronoms employés'),
    EduscolObjective(id: 'c1_l1_ps4', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'PS', text: 'Construire à l\'oral un système de temps de plus en plus efficace'),
    EduscolObjective(id: 'c1_l1_ps5', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'PS', text: 'Formuler des énoncés de plus en plus complexes'),
    EduscolObjective(id: 'c1_l1_ms3', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'MS', text: 'Diversifier les pronoms employés'),
    EduscolObjective(id: 'c1_l1_ms4', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'MS', text: 'Construire à l\'oral un système de temps de plus en plus efficace'),
    EduscolObjective(id: 'c1_l1_ms5', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'MS', text: 'Formuler des énoncés de plus en plus complexes'),
    EduscolObjective(id: 'c1_l1_gs3', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'GS', text: 'Diversifier les pronoms employés'),
    EduscolObjective(id: 'c1_l1_gs4', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'GS', text: 'Construire à l\'oral un système de temps de plus en plus efficace'),
    EduscolObjective(id: 'c1_l1_gs5', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Développer sa syntaxe', level: 'GS', text: 'Formuler des énoncés de plus en plus complexes'),
    EduscolObjective(id: 'c1_l1_ps6', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Articuler distinctement', level: 'PS', text: 'Articuler distinctement les couples de consonnes proches suivants : t/k, f/s, m/n'),
    EduscolObjective(id: 'c1_l1_ms6', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Articuler distinctement', level: 'MS', text: 'Distinguer et produire correctement les nasales : é/in, a/an, o/on'),
    EduscolObjective(id: 'c1_l1_ms7', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Articuler distinctement', level: 'MS', text: 'Articuler distinctement les couples de consonnes proches suivants : f/v, s/z, p/b, t/d, k/g'),
    EduscolObjective(id: 'c1_l1_gs6', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Articuler distinctement', level: 'GS', text: 'Prononcer correctement les couples de consonnes proches suivants : ch/s, ch/j, ch/z'),
    EduscolObjective(id: 'c1_l1_gs7', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Articuler distinctement', level: 'GS', text: 'Prononcer correctement les doubles consonnes : br/cr/bl/pl/sl'),
    EduscolObjective(id: 'c1_l1_ps7', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'PS', text: 'Entrer en communication verbale avec un adulte ou un autre élève'),
    EduscolObjective(id: 'c1_l1_ps8', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'PS', text: 'Dire ce qu\'on fait'),
    EduscolObjective(id: 'c1_l1_ps9', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'PS', text: 'Dire ce qu\'on a fait et, peu à peu, ce qu\'on va faire'),
    EduscolObjective(id: 'c1_l1_ps10', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'PS', text: 'Prendre part à l\'oralisation d\'un court texte mémorisé'),
    EduscolObjective(id: 'c1_l1_ms8', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'MS', text: 'Dire ce qu\'on va faire'),
    EduscolObjective(id: 'c1_l1_ms9', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'MS', text: 'Dire comment on a fait ou comment on va faire'),
    EduscolObjective(id: 'c1_l1_ms10', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'MS', text: 'Oraliser un court texte mémorisé'),
    EduscolObjective(id: 'c1_l1_ms11', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'MS', text: 'Participer à des échanges en restant dans le propos'),
    EduscolObjective(id: 'c1_l1_gs8', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'GS', text: 'Décrire une action ou une activité qui a été menée par un autre élève'),
    EduscolObjective(id: 'c1_l1_gs9', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'GS', text: 'Se faire comprendre, par le truchement du langage, d\'un adulte qui ne connait rien à la situation évoquée'),
    EduscolObjective(id: 'c1_l1_gs10', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'GS', text: 'Participer à une conversation avec un adulte ou des pairs et reformuler son propos s\'il n\'a pas été compris'),
    EduscolObjective(id: 'c1_l1_gs11', domainId: 'd1_langage', subdomainId: 'c1_l1', theme: 'Produire des discours variés', level: 'GS', text: 'Émettre une hypothèse'),
    // Passer de l'oral à l'écrit : se préparer à apprendre à lire
    EduscolObjective(id: 'c1_l2_ps1', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'PS', text: 'Identifier les sons de la langue, lors de situations d\'écoute proposées par le professeur'),
    EduscolObjective(id: 'c1_l2_ps2', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'PS', text: 'Identifier un mot donné à l\'oral dans une phrase, dans un texte'),
    EduscolObjective(id: 'c1_l2_ps3', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'PS', text: 'Scander les syllabes d\'un mot'),
    EduscolObjective(id: 'c1_l2_ps4', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'PS', text: 'Dire des comptines courtes comprenant des phonèmes proches'),
    EduscolObjective(id: 'c1_l2_ps5', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'PS', text: 'Reconnaitre et nommer certaines lettres de son prénom écrit en capitales'),
    EduscolObjective(id: 'c1_l2_ms1', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Utiliser la voix parlée, chantée et les possibilités vocales (imitation de sons, onomatopées) afin d\'expérimenter différents sons'),
    EduscolObjective(id: 'c1_l2_ms2', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Entendre, discriminer des phonèmes'),
    EduscolObjective(id: 'c1_l2_ms3', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Scander les syllabes d\'un mot'),
    EduscolObjective(id: 'c1_l2_ms4', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Manipuler les syllabes d\'un mot (ajout, suppression, permutation, répétition, fusion, substitution)'),
    EduscolObjective(id: 'c1_l2_ms5', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Dire des comptines courtes comprenant des phonèmes proches'),
    EduscolObjective(id: 'c1_l2_ms6', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Nommer les lettres de son prénom et quelques lettres de mots connus (le professeur nomme systématiquement les lettres)'),
    EduscolObjective(id: 'c1_l2_ms7', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Connaitre la correspondance entre les lettres scriptes majuscules et minuscules et les lettres cursives minuscules'),
    EduscolObjective(id: 'c1_l2_ms8', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'MS', text: 'Donner les valeurs sonores de quelques lettres de mots simples connus'),
    EduscolObjective(id: 'c1_l2_gs1', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Utiliser les possibilités sonores de la voix'),
    EduscolObjective(id: 'c1_l2_gs2', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Augmenter sa mémoire auditive et sa capacité de concentration'),
    EduscolObjective(id: 'c1_l2_gs3', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Supprimer, ajouter, remplacer, inverser, substituer, fusionner les syllabes d\'un mot'),
    EduscolObjective(id: 'c1_l2_gs4', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Repérer et produire des rimes et des assonances'),
    EduscolObjective(id: 'c1_l2_gs5', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Entendre, discriminer, manipuler des phonèmes'),
    EduscolObjective(id: 'c1_l2_gs6', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Connaitre le nom des lettres de l\'alphabet'),
    EduscolObjective(id: 'c1_l2_gs7', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Connaitre les différentes graphies d\'une même lettre (majuscule lettre capitale ; minuscules scriptes ; cursives)'),
    EduscolObjective(id: 'c1_l2_gs8', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Distinguer des lettres visuellement proches (b/d, c/e/o, p/q) grâce à leur écriture cursive et les nommer correctement'),
    EduscolObjective(id: 'c1_l2_gs9', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Connaitre le nom des lettres de l\'alphabet et leur valeur sonore hormis les occlusives'),
    EduscolObjective(id: 'c1_l2_gs10', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Acquérir les habiletés phonologiques et le principe alphabétique', level: 'GS', text: 'Discriminer des mots auditivement proches'),
    EduscolObjective(id: 'c1_l2_ps6', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'S\'éveiller à la diversité linguistique', level: 'PS', text: 'Écouter des chants, des comptines, des histoires connues dans des versions en français et en langue étrangère'),
    EduscolObjective(id: 'c1_l2_ms9', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'S\'éveiller à la diversité linguistique', level: 'MS', text: 'Participer à des jeux dans une autre langue : jeux de doigts, rondes, jeux dansés, mimes, jeux de cour, jeux de cartes'),
    EduscolObjective(id: 'c1_l2_ms10', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'S\'éveiller à la diversité linguistique', level: 'MS', text: 'Comparer des histoires lues en français et dans une autre langue'),
    EduscolObjective(id: 'c1_l2_ps7', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'PS', text: 'Repérer les outils fonctionnels utilisés quotidiennement en classe (étiquette du prénom, emploi du temps, affiches, etc.)'),
    EduscolObjective(id: 'c1_l2_ps8', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'PS', text: 'Reconnaitre quelques écrits utilisés et produits en classe (comptines, recettes, carnet de lecteur)'),
    EduscolObjective(id: 'c1_l2_ps9', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'PS', text: 'Reconnaitre un personnage, le nommer et le situer dans les illustrations'),
    EduscolObjective(id: 'c1_l2_ps10', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'PS', text: 'Comprendre des histoires où l\'enchainement des actions peut être rattaché à des expériences connues de la vie quotidienne (le bain, le coucher, etc.)'),
    EduscolObjective(id: 'c1_l2_ms11', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'MS', text: 'Reconnaitre, nommer et identifier la fonction de différents écrits rencontrés dans la vie courante'),
    EduscolObjective(id: 'c1_l2_ms12', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'MS', text: 'Prendre conscience de la notion de destinataire et de contenu de la requête adressée par un écrit'),
    EduscolObjective(id: 'c1_l2_ms13', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'MS', text: 'Identifier et utiliser quotidiennement des outils fonctionnels pour se repérer, s\'organiser, ranger'),
    EduscolObjective(id: 'c1_l2_ms14', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'MS', text: 'Identifier et décrire le personnage principal et les personnages secondaires'),
    EduscolObjective(id: 'c1_l2_ms15', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'MS', text: 'Comprendre des histoires dont les actions sont organisées autour d\'une structure répétitive (rencontres successives) et commencer à comprendre les informations implicites (émotions, états et sentiments des personnages)'),
    EduscolObjective(id: 'c1_l2_gs11', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Différencier les types d\'écrits et associer un écrit à un projet d\'écriture ou de communication'),
    EduscolObjective(id: 'c1_l2_gs12', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Repérer et dégager la structure et l\'organisation (mise en page, typographie) de formes d\'écrits fréquemment utilisés en classe (structure de la lettre, de la recette, du conte, d\'un écrit documentaire, d\'une notice de fabrication)'),
    EduscolObjective(id: 'c1_l2_gs13', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Construire les caractéristiques des personnages archétypaux (loup, princesse, ogre, sorcière, renard, fée, etc.)'),
    EduscolObjective(id: 'c1_l2_gs14', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Comprendre des histoires où l\'enchainement des actions est lié au destin de personnages centraux ou secondaires qui évoluent et interagissent, dans des lieux diversifiés'),
    EduscolObjective(id: 'c1_l2_gs15', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Comprendre les émotions, les intentions et les sentiments qui animent les personnages'),
    EduscolObjective(id: 'c1_l2_gs16', domainId: 'd1_langage', subdomainId: 'c1_l2', theme: 'Écouter et comprendre différentes formes d\'écrits', level: 'GS', text: 'Établir un lien entre la lecture effectuée et sa propre expérience'),
    // Passer de l'oral à l'écrit : se préparer à apprendre à écrire
    EduscolObjective(id: 'c1_l3_ps1', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'PS', text: 'Participer aux activités de motricité générale, de motricité fine et aux exercices de graphismes ;'),
    EduscolObjective(id: 'c1_l3_ps2', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'PS', text: 'Guider son geste par le regard lorsqu\'il trace ou écrit ;'),
    EduscolObjective(id: 'c1_l3_ps3', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'PS', text: 'Prendre des repères spatiaux sur le support utilisé pour tracer'),
    EduscolObjective(id: 'c1_l3_ms1', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'MS', text: 'Adopter une posture adaptée au geste d\'écriture'),
    EduscolObjective(id: 'c1_l3_ms2', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'MS', text: 'Adopter une préhension correcte du stylo et s\'entrainer à ne pas le lever en écrivant'),
    EduscolObjective(id: 'c1_l3_ms3', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'MS', text: 'Utiliser de façon coordonnée les quatre articulations qui servent à tenir et guider le crayon (épaule, coude, poignet, doigts)'),
    EduscolObjective(id: 'c1_l3_ms4', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'MS', text: 'Tracer des lettres capitales'),
    EduscolObjective(id: 'c1_l3_ms5', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'MS', text: 'S\'initier aux tracés de l\'écriture cursive'),
    EduscolObjective(id: 'c1_l3_gs1', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'GS', text: 'Tenir correctement son stylo par la pince des doigts et utiliser de façon coordonnée les quatre articulations (épaule, coude, poignet, doigts)'),
    EduscolObjective(id: 'c1_l3_gs2', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'GS', text: 'Travailler la ligature entre deux lettres'),
    EduscolObjective(id: 'c1_l3_gs3', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Apprendre le geste d\'écriture', level: 'GS', text: 'Tracer des lettres en écriture cursive, les enchainer'),
    EduscolObjective(id: 'c1_l3_ps4', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'PS', text: 'Percevoir que l\'écrit encode l\'oral'),
    EduscolObjective(id: 'c1_l3_ps5', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'PS', text: 'Utiliser un support écrit connu'),
    EduscolObjective(id: 'c1_l3_ps6', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'PS', text: 'Mimer la posture et les gestes d\'écriture de l\'adulte lors de la production de traces qui s\'apparentent à de l\'écriture'),
    EduscolObjective(id: 'c1_l3_ps7', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'PS', text: 'Tracer volontairement des signes abstraits dont on comprend qu\'il ne s\'agit pas de dessins, mais de lettres'),
    EduscolObjective(id: 'c1_l3_ms6', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Comprendre que lorsque l\'adulte lit un même écrit plusieurs fois, ce qu\'il lit est toujours identique'),
    EduscolObjective(id: 'c1_l3_ms7', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Comprendre que l\'écrit code des sons'),
    EduscolObjective(id: 'c1_l3_ms8', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Proposer au professeur, lors d\'une activité de dictée à l\'adulte, le contenu d\'un court message, stabiliser un énoncé oral et le mémoriser pour pouvoir ensuite le dicter au professeur'),
    EduscolObjective(id: 'c1_l3_ms9', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Comparer la longueur d\'un texte écrit et la durée du texte entendu'),
    EduscolObjective(id: 'c1_l3_ms10', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Savoir que le sens de la lecture est de gauche à droite et de haut en bas'),
    EduscolObjective(id: 'c1_l3_ms11', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'MS', text: 'Chercher parmi les outils à sa disposition des modèles qui seront réutilisés dans un essai d\'écriture'),
    EduscolObjective(id: 'c1_l3_gs4', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Segmenter l\'oral en mots, les mots en syllabes, quelques syllabes en phonèmes'),
    EduscolObjective(id: 'c1_l3_gs5', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Comprendre que l\'écrit encode l\'oral et que les sons de la langue sont codés par des lettres'),
    EduscolObjective(id: 'c1_l3_gs6', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Suivre la trace écrite des yeux lors d\'une relecture par l\'adulte d\'un message produit lors d\'une dictée à l\'adulte'),
    EduscolObjective(id: 'c1_l3_gs7', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Mémoriser la graphie d\'un mot transparent, en s\'appuyant sur la connaissance des lettres et la conscience phonologique et le retranscrire sur un support'),
    EduscolObjective(id: 'c1_l3_gs8', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Réinvestir ses premières connaissances relatives au principe alphabétique pour produire un écrit'),
    EduscolObjective(id: 'c1_l3_gs9', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Se repérer dans l\'alphabet pour retrouver l\'écriture d\'une lettre nécessaire pour produire un écrit'),
    EduscolObjective(id: 'c1_l3_gs10', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Mémoriser l\'écriture de mots transparents ou de syllabes connues pour les réutiliser dans une production d\'écrit'),
    EduscolObjective(id: 'c1_l3_gs11', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Comprendre qu\'il existe une norme pour écrire : ponctuation, majuscules, mise en page, etc'),
    EduscolObjective(id: 'c1_l3_gs12', domainId: 'd1_langage', subdomainId: 'c1_l3', theme: 'Produire de premiers écrits', level: 'GS', text: 'Persévérer pour mener la production d\'écrit à son terme : préparation, énonciation et révision'),
    // Se déplacer
    EduscolObjective(id: 'c1_p1_ps1', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'PS', text: 'Manipuler et lancer des objets avec des intentions motrices différentes'),
    EduscolObjective(id: 'c1_p1_ps2', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'PS', text: 'Courir de manière variée et coordonnée'),
    EduscolObjective(id: 'c1_p1_ps3', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'PS', text: 'Sauter sans élan un obstacle'),
    EduscolObjective(id: 'c1_p1_ps4', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'PS', text: 'Se situer dans un espace proche et connu en utilisant des indices présents dans l\'environnement'),
    EduscolObjective(id: 'c1_p1_ms1', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'MS', text: 'Lancer loin de manière coordonnée'),
    EduscolObjective(id: 'c1_p1_ms2', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'MS', text: 'Courir vite en ligne droite sur une distance ou une durée courte'),
    EduscolObjective(id: 'c1_p1_ms3', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'MS', text: 'Sauter sans élan plusieurs obstacles'),
    EduscolObjective(id: 'c1_p1_ms4', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'MS', text: 'Se situer dans un espace élargi et connu grâce à des indices prélevés dans l\'environnement'),
    EduscolObjective(id: 'c1_p1_gs1', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'GS', text: 'Lancer loin et avec précision différents objets'),
    EduscolObjective(id: 'c1_p1_gs2', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'GS', text: 'Courir de plus en plus longtemps sans s\'arrêter'),
    EduscolObjective(id: 'c1_p1_gs3', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'GS', text: 'Courir vite et franchir un obstacle sur une distance courte'),
    EduscolObjective(id: 'c1_p1_gs4', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'GS', text: 'Coordonner ses actions et ses déplacements pour lancer et pour sauter haut ou loin'),
    EduscolObjective(id: 'c1_p1_gs5', domainId: 'd3_physique', subdomainId: 'c1_p1', theme: 'Manipuler, courir, sauter, lancer, s\'orienter', level: 'GS', text: 'Se situer dans un milieu moins connu grâce à des indices prélevés dans l\'environnement'),
    // Construire des équilibres
    EduscolObjective(id: 'c1_p2_ps1', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'PS', text: 'Développer de nouveaux équilibres par des modes de déplacement variés'),
    EduscolObjective(id: 'c1_p2_ps2', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'PS', text: 'Développer de nouveaux équilibres dans des environnements de pratiques inhabituels et sécurisés'),
    EduscolObjective(id: 'c1_p2_ms1', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'MS', text: 'Développer de nouveaux équilibres par des déplacements impliquant une perte de repères habituels'),
    EduscolObjective(id: 'c1_p2_ms2', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'MS', text: 'Comprendre l\'intérêt des règles de sécurité dans des activités et environnements inhabituels'),
    EduscolObjective(id: 'c1_p2_gs1', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'GS', text: 'Construire de nouveaux équilibres par des déplacements impliquant une combinaison d\'actions'),
    EduscolObjective(id: 'c1_p2_gs2', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'GS', text: 'Explorer le milieu aquatique et développer une nouvelle locomotion dans l\'eau'),
    EduscolObjective(id: 'c1_p2_gs3', domainId: 'd3_physique', subdomainId: 'c1_p2', theme: 'Tourner, se suspendre, se renverser, grimper, rouler, glisser, nager', level: 'GS', text: 'Respecter les règles de sécurité pour soi et pour les autres'),
    // S'exprimer avec son corps
    EduscolObjective(id: 'c1_p3_ps1', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'PS', text: 'Découvrir et explorer le mouvement comme vecteur d\'expression'),
    EduscolObjective(id: 'c1_p3_ps2', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'PS', text: 'Oser s\'exprimer avec son corps seul et avec les autres en répondant à une consigne simple'),
    EduscolObjective(id: 'c1_p3_ps3', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'PS', text: 'Observer pour produire et reproduire un ou plusieurs mouvements avec une intention d\'expression'),
    EduscolObjective(id: 'c1_p3_ms1', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'MS', text: 'Découvrir et explorer le geste dansé'),
    EduscolObjective(id: 'c1_p3_ms2', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'MS', text: 'Découvrir l\'espace scénique'),
    EduscolObjective(id: 'c1_p3_ms3', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'MS', text: 'Développer une posture de spectateur et de spectatrice actifs'),
    EduscolObjective(id: 'c1_p3_gs1', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'GS', text: 'Enrichir le geste dansé par de nouvelles coordinations motrices, issues également des arts du cirque'),
    EduscolObjective(id: 'c1_p3_gs2', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'GS', text: 'Explorer l\'ensemble de l\'espace scénique en variant les inducteurs (objets, mondes sonores, modes de déplacements, etc.) pour créer des effets'),
    EduscolObjective(id: 'c1_p3_gs3', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'GS', text: 'Danser, seul ou à plusieurs, en créant et en reproduisant un ou plusieurs gestes et déplacements'),
    EduscolObjective(id: 'c1_p3_gs4', domainId: 'd3_physique', subdomainId: 'c1_p3', theme: 'Explorer, s\'exprimer, danser, observer', level: 'GS', text: 'Adopter une posture de spectateur et de spectatrice actifs'),
    // Coopérer et s'opposer
    EduscolObjective(id: 'c1_p4_ps1', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'PS', text: 'Comprendre et s\'approprier un rôle dans les formes de jeu les plus simples'),
    EduscolObjective(id: 'c1_p4_ps2', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'PS', text: 'Explorer différents jeux moteurs vécus en interindividuel ou en collectif'),
    EduscolObjective(id: 'c1_p4_ps3', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'PS', text: 'Éprouver le plaisir de jouer dans le respect des autres et des règles communes'),
    EduscolObjective(id: 'c1_p4_ms1', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'MS', text: 'Jouer en coopérant'),
    EduscolObjective(id: 'c1_p4_ms2', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'MS', text: 'Jouer en exerçant des rôles différents : attaquant, attaquante et défenseur, défenseuse'),
    EduscolObjective(id: 'c1_p4_ms3', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'MS', text: 'Coopérer dans le respect des autres et des règles communes'),
    EduscolObjective(id: 'c1_p4_gs1', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'GS', text: 'Élaborer seul ou à plusieurs des stratégies pour gagner un jeu'),
    EduscolObjective(id: 'c1_p4_gs2', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'GS', text: 'Jouer en exerçant des rôles différents : attaquant, attaquante, défenseur, défenseuse et arbitre'),
    EduscolObjective(id: 'c1_p4_gs3', domainId: 'd3_physique', subdomainId: 'c1_p4', theme: 'Coopérer, s\'opposer, respecter', level: 'GS', text: 'Éprouver le plaisir de coopérer et de s\'opposer dans le respect des autres et des règles communes'),
    // Arts visuels
    EduscolObjective(id: 'c1_a1_ps1', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'PS', text: 'S\'exercer au dessin pour développer son habileté motrice'),
    EduscolObjective(id: 'c1_a1_ps2', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'PS', text: 'S\'exercer progressivement au dessin avec une intention de représentation'),
    EduscolObjective(id: 'c1_a1_ms1', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'MS', text: 'Expérimenter la diversité des outils, des supports, des matériaux et faire des choix'),
    EduscolObjective(id: 'c1_a1_ms2', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'MS', text: 'S\'exercer au dessin avec une intention de représentation'),
    EduscolObjective(id: 'c1_a1_gs1', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'GS', text: 'Dessiner pour représenter sur la base d\'un modèle'),
    EduscolObjective(id: 'c1_a1_gs2', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'GS', text: 'Dessiner pour représenter un personnage ou un évènement fictif'),
    EduscolObjective(id: 'c1_a1_gs3', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'GS', text: 'Participer à la réalisation d\'une œuvre collective à partir d\'une consigne ou d\'un problème à résoudre'),
    EduscolObjective(id: 'c1_a1_gs4', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Dessiner', level: 'GS', text: 'Utiliser le vocabulaire spécifique au dessin'),
    EduscolObjective(id: 'c1_a1_ps3', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'PS', text: 'Explorer des gestes et commencer à les associer à des types de tracés précis'),
    EduscolObjective(id: 'c1_a1_ps4', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'PS', text: 'Repérer des motifs graphiques issus de son environnement proche'),
    EduscolObjective(id: 'c1_a1_ps5', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'PS', text: 'Découvrir des expressions graphiques dans des œuvres d\'art'),
    EduscolObjective(id: 'c1_a1_ms3', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'MS', text: 'Exercer et développer sa motricité fine'),
    EduscolObjective(id: 'c1_a1_ms4', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'MS', text: 'Repérer des motifs graphiques issus de son environnement'),
    EduscolObjective(id: 'c1_a1_ms5', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'MS', text: 'Reproduire et créer des motifs de plus en plus élaborés'),
    EduscolObjective(id: 'c1_a1_gs5', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'GS', text: 'Transformer ou détourner des motifs du répertoire de la classe pour observer les effets produits'),
    EduscolObjective(id: 'c1_a1_gs6', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'GS', text: 'Créer de nouveaux motifs'),
    EduscolObjective(id: 'c1_a1_gs7', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'S\'exercer au graphisme artistique', level: 'GS', text: 'Réaliser une composition à partir de plusieurs contraintes'),
    EduscolObjective(id: 'c1_a1_ps6', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'PS', text: 'Explorer l\'usage des outils et observer leurs effets sur le geste'),
    EduscolObjective(id: 'c1_a1_ps7', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'PS', text: 'Utiliser différents médiums et observer leurs effets sur les couleurs, les formes et les volumes'),
    EduscolObjective(id: 'c1_a1_ps8', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'PS', text: 'Expérimenter la résistance de certains matériaux'),
    EduscolObjective(id: 'c1_a1_ps9', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'PS', text: 'Réaliser individuellement ou collectivement une production plastique en volume'),
    EduscolObjective(id: 'c1_a1_ms6', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'MS', text: 'S\'approprier les constituants plastiques (couleurs, formes, matières, rythmes, etc.)'),
    EduscolObjective(id: 'c1_a1_ms7', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'MS', text: 'Réaliser une composition en deux ou trois dimensions en fonction d\'un projet individuel ou collectif'),
    EduscolObjective(id: 'c1_a1_ms8', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'MS', text: 'Découvrir différentes formes d\'expression artistique'),
    EduscolObjective(id: 'c1_a1_gs8', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'GS', text: 'Réaliser des compositions plastiques, seul ou en petit groupe, en choisissant et combinant des matériaux et en réinvestissant des techniques et des procédés'),
    EduscolObjective(id: 'c1_a1_gs9', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Réaliser des compositions planes ou en volume', level: 'GS', text: 'Se familiariser avec différentes formes d\'expression artistique'),
    EduscolObjective(id: 'c1_a1_ps10', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'PS', text: 'Apprendre à regarder avec attention et à identifier des éléments visuels'),
    EduscolObjective(id: 'c1_a1_ps11', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'PS', text: 'Découvrir quelques éléments constitutifs d\'une illustration'),
    EduscolObjective(id: 'c1_a1_ms9', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'MS', text: 'Différencier une image fixe d\'une image animée'),
    EduscolObjective(id: 'c1_a1_ms10', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'MS', text: 'Fabriquer des images à partir d\'images existantes'),
    EduscolObjective(id: 'c1_a1_ms11', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'MS', text: 'Identifier et nommer des éléments graphiques d\'une illustration'),
    EduscolObjective(id: 'c1_a1_gs10', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'GS', text: 'Différencier des types d\'images (portrait, paysage, nature morte, etc.)'),
    EduscolObjective(id: 'c1_a1_gs11', domainId: 'd4_art', subdomainId: 'c1_a1', theme: 'Observer, comprendre et transformer des images', level: 'GS', text: 'Identifier et nommer des éléments esthétiques d\'une illustration'),
    // Les univers sonores
    EduscolObjective(id: 'c1_a2_ps1', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'PS', text: 'Dépasser les usages courants de la voix'),
    EduscolObjective(id: 'c1_a2_ps2', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'PS', text: 'Chanter en se faisant comprendre des autres'),
    EduscolObjective(id: 'c1_a2_ps3', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'PS', text: 'Dire ou chanter au moins cinq comptines'),
    EduscolObjective(id: 'c1_a2_ms1', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'MS', text: 'Découvrir et explorer la richesse de sa voix'),
    EduscolObjective(id: 'c1_a2_ms2', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'MS', text: 'Chanter en exprimant une émotion'),
    EduscolObjective(id: 'c1_a2_ms3', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'MS', text: 'Dire ou chanter au moins huit comptines ou chants, en réinvestissant les comptines apprises l\'année précédente'),
    EduscolObjective(id: 'c1_a2_gs1', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'GS', text: 'Développer et affirmer son inventivité avec sa voix'),
    EduscolObjective(id: 'c1_a2_gs2', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'GS', text: 'Trouver sa place dans un collectif chantant'),
    EduscolObjective(id: 'c1_a2_gs3', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Jouer avec sa voix et acquérir un répertoire de comptines et de chansons', level: 'GS', text: 'Dire ou chanter au moins dix comptines ou chants, en réinvestissant ceux appris les années antérieures'),
    EduscolObjective(id: 'c1_a2_ps4', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'PS', text: 'Explorer les possibilités sonores de son corps, d\'objets et d\'instruments'),
    EduscolObjective(id: 'c1_a2_ps5', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'PS', text: 'Découvrir les possibilités expressives de son corps, d\'objets et d\'instruments'),
    EduscolObjective(id: 'c1_a2_ps6', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'PS', text: 'Observer et commenter ce que font les camarades de classe pour produire des sons avec leur corps, des objets et des instruments'),
    EduscolObjective(id: 'c1_a2_ms4', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'MS', text: 'Produire des sons à partir de son corps, d\'objets et d\'instruments'),
    EduscolObjective(id: 'c1_a2_ms5', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'MS', text: 'Adapter son geste pour produire un son en fonction d\'une consigne'),
    EduscolObjective(id: 'c1_a2_ms6', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'MS', text: 'Reproduire un rythme simple collectivement'),
    EduscolObjective(id: 'c1_a2_gs4', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'GS', text: 'Explorer le lien entre le son et le geste'),
    EduscolObjective(id: 'c1_a2_gs5', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'GS', text: 'Créer un paysage sonore en répondant à une consigne simple avec son corps, des objets ou des instruments'),
    EduscolObjective(id: 'c1_a2_gs6', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Explorer des instruments, utiliser les sonorités du corps', level: 'GS', text: 'Créer collectivement une production musicale'),
    EduscolObjective(id: 'c1_a2_ps7', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'PS', text: 'Traduire la musique entendue en mouvements'),
    EduscolObjective(id: 'c1_a2_ps8', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'PS', text: 'Développer une posture d\'écoute'),
    EduscolObjective(id: 'c1_a2_ms7', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'MS', text: 'Traduire la musique entendue en mouvements et en mots'),
    EduscolObjective(id: 'c1_a2_ms8', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'MS', text: 'Exprimer ses émotions après l\'écoute d\'un extrait musical'),
    EduscolObjective(id: 'c1_a2_ms9', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'MS', text: 'Découvrir au moins deux œuvres musicales patrimoniales'),
    EduscolObjective(id: 'c1_a2_gs7', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'GS', text: 'Traduire la musique entendue en dessin'),
    EduscolObjective(id: 'c1_a2_gs8', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'GS', text: 'Écouter une œuvre musicale patrimoniale pour repérer des éléments musicaux significatifs'),
    EduscolObjective(id: 'c1_a2_gs9', domainId: 'd4_art', subdomainId: 'c1_a2', theme: 'Affiner son écoute', level: 'GS', text: 'Connaitre au moins trois œuvres musicales patrimoniales'),
    // Le spectacle vivant
    EduscolObjective(id: 'c1_a3_ps1', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'PS', text: 'Découvrir différentes façons d\'exprimer ses émotions par le corps'),
    EduscolObjective(id: 'c1_a3_ps2', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'PS', text: 'Découvrir des rôles simples'),
    EduscolObjective(id: 'c1_a3_ps3', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'PS', text: 'Découvrir le jeu dans une mise en scène collective'),
    EduscolObjective(id: 'c1_a3_ms1', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'MS', text: 'Se familiariser avec l\'expression des émotions par le corps et la voix'),
    EduscolObjective(id: 'c1_a3_ms2', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'MS', text: 'Se familiariser avec des rôles simples'),
    EduscolObjective(id: 'c1_a3_ms3', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'MS', text: 'Se familiariser avec le jeu dans une mise en scène collective'),
    EduscolObjective(id: 'c1_a3_gs1', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'GS', text: 'Explorer des enchainements d\'émotions par le corps et la voix'),
    EduscolObjective(id: 'c1_a3_gs2', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'GS', text: 'Explorer des rôles simples'),
    EduscolObjective(id: 'c1_a3_gs3', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Pratiquer', level: 'GS', text: 'Explorer le jeu dans une mise en scène collective'),
    EduscolObjective(id: 'c1_a3_ps4', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'PS', text: 'Découvrir des œuvres adaptées'),
    EduscolObjective(id: 'c1_a3_ps5', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'PS', text: 'Découvrir l\'espace scénique'),
    EduscolObjective(id: 'c1_a3_ms4', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'MS', text: 'Se familiariser avec l\'espace scénique'),
    EduscolObjective(id: 'c1_a3_ms5', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'MS', text: 'Se familiariser avec des œuvres adaptées'),
    EduscolObjective(id: 'c1_a3_ms6', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'MS', text: 'Rencontrer des artistes'),
    EduscolObjective(id: 'c1_a3_gs4', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'GS', text: 'Explorer l\'espace scénique'),
    EduscolObjective(id: 'c1_a3_gs5', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'GS', text: 'Explorer des œuvres adaptées'),
    EduscolObjective(id: 'c1_a3_gs6', domainId: 'd4_art', subdomainId: 'c1_a3', theme: 'Fréquenter et devenir spectateur et spectatrice', level: 'GS', text: 'Rencontrer des artistes et des professionnels'),
    // Découvrir les nombres
    EduscolObjective(id: 'c1_m1_ps1', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Comprendre qu\'une quantité d\'objets ne dépend ni de la nature de ces objets ni de leur organisation spatiale'),
    EduscolObjective(id: 'c1_m1_ps2', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Comprendre que : si on ajoute un objet à une collection, le nombre qui désigne sa quantité est le suivant dans la suite orale des noms des nombres ; dans la suite orale des noms des nombres, chaque nombre s\'obtient en ajoutant un au nombre précédent'),
    EduscolObjective(id: 'c1_m1_ps3', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Dénombrer une collection d\'objets (jusqu\'à trois, voire quatre)'),
    EduscolObjective(id: 'c1_m1_ps4', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Constituer une collection (jusqu\'à trois, voire quatre objets) d\'un cardinal donné'),
    EduscolObjective(id: 'c1_m1_ps5', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Comparer des quantités'),
    EduscolObjective(id: 'c1_m1_ps6', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Composer et décomposer des nombres (deux, trois, voire quatre)'),
    EduscolObjective(id: 'c1_m1_ps7', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Manipuler et verbaliser des compositions et des décompositions de nombres. Cela permet d\'installer le fait que, dans une composition, l\'ordre ne compte pas ; ces compositions et décompositions permettent de dénombrer plus efficacement que par le comptage un à un'),
    EduscolObjective(id: 'c1_m1_ps8', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Associer une quantité, le nom d\'un nombre et une écriture chiffrée'),
    EduscolObjective(id: 'c1_m1_ps9', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'PS', text: 'Connaitre la comptine numérique de un à six'),
    EduscolObjective(id: 'c1_m1_ms1', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Poursuivre la compréhension qu\'une quantité d\'objets ne dépend ni de leur nature ni de leur organisation spatiale'),
    EduscolObjective(id: 'c1_m1_ms2', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Poursuivre la compréhension des faits suivants : si on ajoute un objet à une collection, le nombre qui désigne sa quantité est le suivant dans la suite orale des noms des nombres ; dans la suite orale des nombres, chaque nombre s\'obtient en ajoutant un au nombre précédent'),
    EduscolObjective(id: 'c1_m1_ms3', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Parcourir une collection en passant une et une seule fois par chacun de ses éléments'),
    EduscolObjective(id: 'c1_m1_ms4', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Dénombrer une collection d\'objets (jusqu\'à six)'),
    EduscolObjective(id: 'c1_m1_ms5', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Constituer une collection d\'un cardinal donné (jusqu\'à six objets)'),
    EduscolObjective(id: 'c1_m1_ms6', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Comparer des quantités'),
    EduscolObjective(id: 'c1_m1_ms7', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Composer et décomposer des nombres inférieurs ou égaux à six'),
    EduscolObjective(id: 'c1_m1_ms8', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Manipuler et verbaliser des compositions et des décompositions de nombres. Cela permet d\'installer le fait que, dans une composition, l\'ordre ne compte pas ; ces compositions et décompositions permettent de dénombrer plus efficacement que par le comptage un à un'),
    EduscolObjective(id: 'c1_m1_ms9', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Associer une quantité, le nom d\'un nombre et une écriture chiffrée'),
    EduscolObjective(id: 'c1_m1_ms10', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Écrire en chiffres les nombres de un à six'),
    EduscolObjective(id: 'c1_m1_ms11', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'MS', text: 'Connaitre la comptine numérique de un à douze'),
    EduscolObjective(id: 'c1_m1_gs1', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Poursuivre la compréhension qu\'une quantité d\'objets ne dépend ni de la nature de ces objets ni de leur organisation spatiale'),
    EduscolObjective(id: 'c1_m1_gs2', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Poursuivre la compréhension des faits suivants : si on ajoute un objet à une collection, le nombre qui désigne sa quantité est le suivant dans la suite orale des noms des nombres ; dans la suite orale des nombres, chaque nombre s\'obtient en ajoutant un au nombre précédent'),
    EduscolObjective(id: 'c1_m1_gs3', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Poursuivre les stratégies de parcours d\'une collection en passant une et une seule fois par chacun de ses éléments'),
    EduscolObjective(id: 'c1_m1_gs4', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Dénombrer une collection d\'objets (jusqu\'à dix, voire au-delà)'),
    EduscolObjective(id: 'c1_m1_gs5', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Constituer une collection d\'un cardinal donné (jusqu\'à dix, voire au- delà)'),
    EduscolObjective(id: 'c1_m1_gs6', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Comparer des quantités'),
    EduscolObjective(id: 'c1_m1_gs7', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Composer et décomposer des nombres inférieurs ou égaux à dix, voire au-delà'),
    EduscolObjective(id: 'c1_m1_gs8', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Manipuler et verbaliser des compositions et des décompositions de nombres. Cela permet d\'installer le fait que, dans une composition, l\'ordre ne compte pas'),
    EduscolObjective(id: 'c1_m1_gs9', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Surcompter (c\'est-à-dire compter de un en un à partir d\'un nombre donné)'),
    EduscolObjective(id: 'c1_m1_gs10', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Associer une quantité, le nom d\'un nombre et une écriture chiffrée'),
    EduscolObjective(id: 'c1_m1_gs11', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Écrire en chiffres les nombres de un à dix'),
    EduscolObjective(id: 'c1_m1_gs12', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer une quantité par un nombre', level: 'GS', text: 'Connaitre et utiliser la comptine numérique jusqu\'à trente'),
    EduscolObjective(id: 'c1_m1_ms12', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'MS', text: 'Comprendre la notion de rang'),
    EduscolObjective(id: 'c1_m1_ms13', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'MS', text: 'Déterminer l\'effet d\'un déplacement sur une position'),
    EduscolObjective(id: 'c1_m1_ms14', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'MS', text: 'Se familiariser avec le début de la bande numérique'),
    EduscolObjective(id: 'c1_m1_gs13', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'GS', text: 'Comprendre la notion de rang d\'un objet'),
    EduscolObjective(id: 'c1_m1_gs14', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'GS', text: 'Déterminer l\'effet d\'un déplacement sur une position'),
    EduscolObjective(id: 'c1_m1_gs15', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'GS', text: 'Comprendre le lien entre un ajout et un avancement et celui entre un retrait et un recul'),
    EduscolObjective(id: 'c1_m1_gs16', domainId: 'd2_maths', subdomainId: 'c1_m1', theme: 'Exprimer un rang ou une position par un nombre', level: 'GS', text: 'Construire la bande numérique jusqu\'à dix'),
    // Utiliser les nombres pour résoudre des problèmes
    EduscolObjective(id: 'c1_m2_ps1', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'PS', text: 'Recherche du tout ou d\'une partie dans un problème de parties-tout'),
    EduscolObjective(id: 'c1_m2_ms1', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'MS', text: 'Rechercher le tout ou une partie dans un problème de parties-tout'),
    EduscolObjective(id: 'c1_m2_ms2', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'MS', text: 'Trouver une position finale à partir d\'une position initiale et d\'un déplacement sur une piste du type du jeu de l\'oie ou sur la bande numérique'),
    EduscolObjective(id: 'c1_m2_ms3', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'MS', text: 'Rechercher le tout dans un problème de groupements'),
    EduscolObjective(id: 'c1_m2_ms4', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'MS', text: 'Rechercher la valeur d\'une part dans un problème de partage équitable'),
    EduscolObjective(id: 'c1_m2_gs1', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer le tout ou une partie dans un problème de parties-tout (d\'abord deux parties, puis éventuellement trois)'),
    EduscolObjective(id: 'c1_m2_gs2', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer la quantité d\'objets ayant été ajoutée ou retirée à une collection à partir de ses quantités initiale et finale'),
    EduscolObjective(id: 'c1_m2_gs3', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer la position finale (respectivement initiale) à partir de la position initiale (respectivement finale) et d\'un déplacement sur une piste du type du jeu de l\'oie ou sur la bande numérique'),
    EduscolObjective(id: 'c1_m2_gs4', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer le cardinal d\'une collection à partir de celui d\'une autre collection et de l\'écart entre les deux'),
    EduscolObjective(id: 'c1_m2_gs5', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer le tout dans un problème de groupement d\'objets'),
    EduscolObjective(id: 'c1_m2_gs6', domainId: 'd2_maths', subdomainId: 'c1_m2', level: 'GS', text: 'Déterminer la valeur d\'une part dans un problème de partage équitable (avec éventuellement un reste)'),
    // Explorer les solides et les formes planes
    EduscolObjective(id: 'c1_m3_ps1', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'PS', text: 'Reconnaitre, trier et classer des objets selon leur forme'),
    EduscolObjective(id: 'c1_m3_ps2', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'PS', text: 'Percevoir l\'invariance de la forme d\'un objet par rapport aux déplacements qu\'il peut subir'),
    EduscolObjective(id: 'c1_m3_ps3', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'PS', text: 'Reproduire des assemblages de solides ou de formes planes'),
    EduscolObjective(id: 'c1_m3_ms1', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'MS', text: 'Reconnaitre et classer des solides (cube, boule, pyramide à base carrée, cylindre) et des formes géométriques planes (triangle, carré, disque)'),
    EduscolObjective(id: 'c1_m3_ms2', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'MS', text: 'Reproduire des assemblages de solides ou de formes planes (au maximum cinq)'),
    EduscolObjective(id: 'c1_m3_gs1', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'GS', text: 'Décrire quelques solides simples : cube, pavé, boule, pyramides à base carrée ou triangulaire, cylindre, cône'),
    EduscolObjective(id: 'c1_m3_gs2', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'GS', text: 'Reconnaitre, trier et classer des formes géométriques planes, indépendamment d\'autres critères comme la couleur, la taille, l\'orientation'),
    EduscolObjective(id: 'c1_m3_gs3', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'GS', text: 'Décrire et nommer quelques figures géométriques simples : carré, rectangle, triangle, disque'),
    EduscolObjective(id: 'c1_m3_gs4', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'GS', text: 'Reproduire des assemblages de solides (au maximum cinq) et de formes planes (au maximum huit)'),
    EduscolObjective(id: 'c1_m3_gs5', domainId: 'd2_maths', subdomainId: 'c1_m3', level: 'GS', text: 'S\'approprier la règle comme outil de tracé'),
    // Explorer des grandeurs : la longueur, la masse
    EduscolObjective(id: 'c1_m4_ps1', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'PS', text: 'Reconnaitre un objet de même longueur qu\'un objet donné'),
    EduscolObjective(id: 'c1_m4_ps2', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'PS', text: 'Comparer des objets selon leur longueur'),
    EduscolObjective(id: 'c1_m4_ms1', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'MS', text: 'Comparer directement des longueurs d\'objets rectilignes et verbaliser le résultat'),
    EduscolObjective(id: 'c1_m4_ms2', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'MS', text: 'Classer des objets rectilignes selon leur longueur'),
    EduscolObjective(id: 'c1_m4_ms3', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'MS', text: 'Ordonner des objets rectilignes selon leur longueur et verbaliser le résultat. La masse'),
    EduscolObjective(id: 'c1_m4_ms4', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'MS', text: 'Comparer les masses de deux objets'),
    EduscolObjective(id: 'c1_m4_gs1', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'GS', text: 'Comparer indirectement des longueurs d\'objets rectilignes'),
    EduscolObjective(id: 'c1_m4_gs2', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'GS', text: 'Ordonner des objets rectilignes selon leur longueur (au maximum cinq)'),
    EduscolObjective(id: 'c1_m4_gs3', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'GS', text: 'Produire un objet rectiligne de même longueur qu\'un objet donné. La masse'),
    EduscolObjective(id: 'c1_m4_gs4', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'GS', text: 'Ordonner les masses de trois objets. Verbaliser les résultats'),
    EduscolObjective(id: 'c1_m4_gs5', domainId: 'd2_maths', subdomainId: 'c1_m4', level: 'GS', text: 'Reconnaitre l\'égalité de deux masses et verbaliser le résultat'),
    // Se familiariser avec les motifs organisés
    EduscolObjective(id: 'c1_m5_ps1', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'PS', text: 'Mémoriser un motif répétitif très simple'),
    EduscolObjective(id: 'c1_m5_ps2', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'PS', text: 'Reproduire un motif répétitif à l\'identique'),
    EduscolObjective(id: 'c1_m5_ms1', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'MS', text: 'Mémoriser un motif répétitif simple'),
    EduscolObjective(id: 'c1_m5_ms2', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'MS', text: 'Reconnaitre un motif répétitif à ses régularités'),
    EduscolObjective(id: 'c1_m5_ms3', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'MS', text: 'Décrire oralement des motifs répétitifs simples de différentes natures, sans nécessairement recourir au vocabulaire spécialisé'),
    EduscolObjective(id: 'c1_m5_ms4', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'MS', text: 'Prolonger l\'amorce d\'un motif répétitif et verbaliser la règle de prolongement utilisée'),
    EduscolObjective(id: 'c1_m5_gs1', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'GS', text: 'Repérer et décrire oralement la structure d\'un motif évolutif (par exemple relevant de la transcription formelle ABAABBAAABBB)'),
    EduscolObjective(id: 'c1_m5_gs2', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'GS', text: 'Identifier la structure d\'un motif répétitif ou évolutif indépendamment des éléments physiques qui le composent'),
    EduscolObjective(id: 'c1_m5_gs3', domainId: 'd2_maths', subdomainId: 'c1_m5', level: 'GS', text: 'Créer des motifs de différentes natures'),
    // Se repérer dans le temps
    EduscolObjective(id: 'c1_t1_ps1', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'PS', text: 'Acquérir les premiers repères temporels'),
    EduscolObjective(id: 'c1_t1_ps2', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'PS', text: 'Identifier les principaux moments d\'une journée'),
    EduscolObjective(id: 'c1_t1_ps3', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'PS', text: 'Connaitre quelques marqueurs temporels'),
    EduscolObjective(id: 'c1_t1_ps4', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'PS', text: 'Aborder la notion de saison à partir de quelques faits observables'),
    EduscolObjective(id: 'c1_t1_ms1', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'MS', text: 'Énoncer le moment de la journée où l\'on se situe'),
    EduscolObjective(id: 'c1_t1_ms2', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'MS', text: 'Établir des jours qui servent de repères dans la semaine'),
    EduscolObjective(id: 'c1_t1_ms3', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'MS', text: 'Savoir que la semaine est une suite de sept jours'),
    EduscolObjective(id: 'c1_t1_ms4', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'MS', text: 'Employer le présent, le futur, le passé composé et commencer éventuellement à employer l\'imparfait pour évoquer des évènements et les resituer dans le temps'),
    EduscolObjective(id: 'c1_t1_ms5', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'MS', text: 'Approfondir la notion de saison par des observations sur la végétation et le climat'),
    EduscolObjective(id: 'c1_t1_gs1', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Situer un évènement dans la semaine'),
    EduscolObjective(id: 'c1_t1_gs2', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Continuer à s\'approprier les temps conjugués (futur simple et futur antérieur) et les jours pour situer les évènements dans la semaine et situer un évènement qui va se produire'),
    EduscolObjective(id: 'c1_t1_gs3', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Énoncer la date'),
    EduscolObjective(id: 'c1_t1_gs4', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Utiliser des mois qui servent de repères pour se situer dans l\'année'),
    EduscolObjective(id: 'c1_t1_gs5', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Nommer la plupart des mois de l\'année'),
    EduscolObjective(id: 'c1_t1_gs6', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', level: 'GS', text: 'Connaitre les saisons'),
    EduscolObjective(id: 'c1_t1_ps5', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'PS', text: 'Situer des moments de la journée les uns par rapport aux autres et commencer à utiliser le présent, le passé composé, le présent à valeur de futur proche'),
    EduscolObjective(id: 'c1_t1_ps6', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'PS', text: 'Ordonner entre eux des moments rituels vécus'),
    EduscolObjective(id: 'c1_t1_ps7', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'PS', text: 'Comprendre et restituer le déroulement d\'évènements quotidiens au sein d\'une histoire simple'),
    EduscolObjective(id: 'c1_t1_ps8', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'PS', text: 'Se projeter dans l\'action que l\'on choisit d\'effectuer'),
    EduscolObjective(id: 'c1_t1_ps9', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'PS', text: 'Commencer à planifier deux activités'),
    EduscolObjective(id: 'c1_t1_ms6', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'MS', text: 'Restituer la chronologie des actions majeures d\'une histoire simple'),
    EduscolObjective(id: 'c1_t1_ms7', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'MS', text: 'Relater et expliquer une action, une procédure en utilisant de premiers connecteurs structurants afin d\'inscrire les activités récurrentes de leur vie quotidienne dans le temps'),
    EduscolObjective(id: 'c1_t1_gs7', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'GS', text: 'Repérer les différentes étapes d\'un processus ou d\'un évènement vécu et les ordonner'),
    EduscolObjective(id: 'c1_t1_gs8', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'GS', text: 'Repérer l\'antériorité d\'une action par rapport à une autre dans un scénario: imparfait, plus-que-parfait, imparfait du verbe « aller » à valeur de futur proche dans le passé'),
    EduscolObjective(id: 'c1_t1_gs9', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'GS', text: 'Ordonner des évènements passés les uns par rapport aux autres, dans l\'année scolaire'),
    EduscolObjective(id: 'c1_t1_gs10', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'S\'approprier la notion de chronologie', level: 'GS', text: 'Relater des évènements passés ou à venir qui indiquent la succession, l\'antériorité, la postériorité et la simultanéité'),
    EduscolObjective(id: 'c1_t1_ps10', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'PS', text: 'Attendre avant d\'obtenir ce que l\'on souhaite'),
    EduscolObjective(id: 'c1_t1_ps11', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'PS', text: 'Repérer le début et la fin d\'une activité'),
    EduscolObjective(id: 'c1_t1_ps12', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'PS', text: 'Connaitre quelques mots qui font référence à la durée'),
    EduscolObjective(id: 'c1_t1_ms8', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'MS', text: 'Percevoir que certaines durées sont stables'),
    EduscolObjective(id: 'c1_t1_ms9', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'MS', text: 'Enrichir le répertoire de mots qui font référence à la durée'),
    EduscolObjective(id: 'c1_t1_gs11', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'GS', text: 'Commencer à utiliser les repères donnés par les professeurs pour organiser son activité dans un temps imparti'),
    EduscolObjective(id: 'c1_t1_gs12', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'GS', text: 'Comparer des durées'),
    EduscolObjective(id: 'c1_t1_gs13', domainId: 'd5_temps_espace', subdomainId: 'c1_t1', theme: 'Construire la notion de durée', level: 'GS', text: 'Comprendre progressivement qu\'il existe un temps long, un passé très éloigné, des évènements antérieurs à notre propre vie'),
    // Se repérer dans l'espace
    EduscolObjective(id: 'c1_t2_ps1', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Réaliser des constructions simples à partir de pièces solides ou de formes planes'),
    EduscolObjective(id: 'c1_t2_ps2', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Orienter un objet ou une forme'),
    EduscolObjective(id: 'c1_t2_ps3', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Manipuler des objets volumineux'),
    EduscolObjective(id: 'c1_t2_ps4', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Orienter un livre ou un autre support d\'écrit'),
    EduscolObjective(id: 'c1_t2_ps5', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Réaliser un trajet, un parcours simple dans l\'école'),
    EduscolObjective(id: 'c1_t2_ps6', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Expérimenter les effets sensoriels de la proximité et de l\'éloignement'),
    EduscolObjective(id: 'c1_t2_ps7', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'PS', text: 'Acquérir les premiers marqueurs qui permettent de se repérer dans l\'espace'),
    EduscolObjective(id: 'c1_t2_ms1', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Réaliser des constructions de pièces solides ou de formes planes à partir d\'une contrainte'),
    EduscolObjective(id: 'c1_t2_ms2', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Situer des objets entre eux'),
    EduscolObjective(id: 'c1_t2_ms3', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Situer des objets par rapport à soi, différencier la proximité de l\'éloignement'),
    EduscolObjective(id: 'c1_t2_ms4', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Orienter et utiliser correctement une feuille de papier'),
    EduscolObjective(id: 'c1_t2_ms5', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Se situer par rapport aux autres'),
    EduscolObjective(id: 'c1_t2_ms6', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'MS', text: 'Employer les marqueurs spatiaux précédemment acquis et en acquérir de nouveaux'),
    EduscolObjective(id: 'c1_t2_gs1', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Réaliser des assemblages complexes'),
    EduscolObjective(id: 'c1_t2_gs2', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Situer des objets dans un ensemble ordonné'),
    EduscolObjective(id: 'c1_t2_gs3', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Situer des objets par rapport à soi, construire une image orientée de son corps'),
    EduscolObjective(id: 'c1_t2_gs4', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Réaliser un trajet, un parcours dans un environnement connu'),
    EduscolObjective(id: 'c1_t2_gs5', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Utiliser une page en respectant les normes d\'écriture'),
    EduscolObjective(id: 'c1_t2_gs6', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Reconnaitre quelques espaces géographiques sur un planisphère'),
    EduscolObjective(id: 'c1_t2_gs7', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Faire l\'expérience de l\'espace', level: 'GS', text: 'Enrichir le lexique relatif à l\'espace de mots plus complexes ou désignant un espace plus éloigné'),
    EduscolObjective(id: 'c1_t2_ps8', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'PS', text: 'Reproduire un parcours simple'),
    EduscolObjective(id: 'c1_t2_ps9', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'PS', text: 'Restituer un déplacement à l\'aide de représentations diverses'),
    EduscolObjective(id: 'c1_t2_ms7', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'MS', text: 'Représenter un espace connu'),
    EduscolObjective(id: 'c1_t2_ms8', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'MS', text: 'Restituer oralement un déplacement à partir d\'une représentation'),
    EduscolObjective(id: 'c1_t2_ms9', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'MS', text: 'Représenter un déplacement'),
    EduscolObjective(id: 'c1_t2_ms10', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'MS', text: 'Composer et représenter divers éléments'),
    EduscolObjective(id: 'c1_t2_gs8', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Reproduire un parcours sur une représentation plane'),
    EduscolObjective(id: 'c1_t2_gs9', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Représenter l\'environnement proche'),
    EduscolObjective(id: 'c1_t2_gs10', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Restituer oralement un déplacement mémorisé'),
    EduscolObjective(id: 'c1_t2_gs11', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Représenter un déplacement'),
    EduscolObjective(id: 'c1_t2_gs12', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Représenter la proximité ou l\'éloignement d\'un sujet'),
    EduscolObjective(id: 'c1_t2_gs13', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Représenter l\'espace', level: 'GS', text: 'Représenter divers éléments sur un plan'),
    EduscolObjective(id: 'c1_t2_ps10', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'PS', text: 'Explorer les différents lieux de l\'école et leur associer des éléments caractéristiques observés'),
    EduscolObjective(id: 'c1_t2_ms11', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'MS', text: 'Caractériser l\'environnement extérieur proche de l\'école'),
    EduscolObjective(id: 'c1_t2_ms12', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'MS', text: 'Découvrir des espaces moins familiers'),
    EduscolObjective(id: 'c1_t2_gs14', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'GS', text: 'Reconnaitre les espaces proches de l\'école et leurs usages'),
    EduscolObjective(id: 'c1_t2_gs15', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'GS', text: 'Reconnaitre des espaces moins familiers'),
    EduscolObjective(id: 'c1_t2_gs16', domainId: 'd5_temps_espace', subdomainId: 'c1_t2', theme: 'Découvrir l\'environnement proche', level: 'GS', text: 'Observer l\'habitat proche de l\'école'),
    // Découvrir le monde du vivant
    EduscolObjective(id: 'c1_v1_ps1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'PS', text: 'Repérer et nommer les caractéristiques morphologiques générales des plantes et des animaux observés avec la classe'),
    EduscolObjective(id: 'c1_v1_ps2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'PS', text: 'Reconnaitre et nommer le mâle et la femelle, le jeune et l\'adulte pour plusieurs espèces animales'),
    EduscolObjective(id: 'c1_v1_ps3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'PS', text: 'Prodiguer des soins nécessaires aux élevages et aux cultures'),
    EduscolObjective(id: 'c1_v1_ms1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'MS', text: 'Reconnaitre une ou plusieurs étapes d\'un cycle de vie à partir de l\'observation d\'animaux et de plantes'),
    EduscolObjective(id: 'c1_v1_ms2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'MS', text: 'Identifier et décrire les besoins essentiels de quelques animaux et de végétaux à partir d\'observations d\'élevage, de cultures de plantes, et des soins prodigués'),
    EduscolObjective(id: 'c1_v1_ms3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'MS', text: 'Observer et nommer le mode de déplacement de quelques animaux en relation avec leur milieu de vie'),
    EduscolObjective(id: 'c1_v1_ms4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'MS', text: 'Respecter la vie sous toutes ses formes'),
    EduscolObjective(id: 'c1_v1_gs1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'GS', text: 'Identifier des éléments morphologiques spécifiques à une espèce végétale ou animale'),
    EduscolObjective(id: 'c1_v1_gs2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'GS', text: 'Reconnaitre les étapes de la vie d\'un animal ou d\'une plante'),
    EduscolObjective(id: 'c1_v1_gs3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'GS', text: 'Décrire les besoins essentiels de quelques animaux ou de végétaux'),
    EduscolObjective(id: 'c1_v1_gs4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir les animaux et les végétaux', level: 'GS', text: 'Contribuer à une action collective favorable à la préservation de la biodiversité dans un milieu proche de l\'école'),
    EduscolObjective(id: 'c1_v1_ps4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'PS', text: 'Nommer et représenter quelques parties du corps humain'),
    EduscolObjective(id: 'c1_v1_ps5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'PS', text: 'Découvrir les sens utilisés lors d\'expériences sensorielles variées'),
    EduscolObjective(id: 'c1_v1_ps6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'PS', text: 'Respecter quelques règles d\'hygiène de vie, à l\'invitation de l\'adulte'),
    EduscolObjective(id: 'c1_v1_ms5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'MS', text: 'Identifier et nommer les parties du corps humain'),
    EduscolObjective(id: 'c1_v1_ms6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'MS', text: 'Identifier et nommer des organes sensoriels et les modalités de perception associées'),
    EduscolObjective(id: 'c1_v1_ms7', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'MS', text: 'Observer des changements liés à sa croissance'),
    EduscolObjective(id: 'c1_v1_ms8', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'MS', text: 'Connaitre quelques règles d\'hygiène corporelle et de propreté'),
    EduscolObjective(id: 'c1_v1_gs5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'GS', text: 'Identifier et nommer quelques articulations et la segmentation des membres'),
    EduscolObjective(id: 'c1_v1_gs6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'GS', text: 'Se représenter avec un corps articulé en mouvement'),
    EduscolObjective(id: 'c1_v1_gs7', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v1', theme: 'Découvrir le corps humain et la santé', level: 'GS', text: 'Connaitre quelques étapes de la vie d\'un enfant jusqu\'à six ans'),
    // Découvrir le monde de la matière et des objets
    EduscolObjective(id: 'c1_v2_ps1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'PS', text: 'Reconnaitre et comparer des matériaux usuels à partir de perceptions sensorielles'),
    EduscolObjective(id: 'c1_v2_ps2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'PS', text: 'Repérer des transformations de matériaux sous l\'effet d\'actions mécaniques avec les mains ou avec des outils'),
    EduscolObjective(id: 'c1_v2_ps3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'PS', text: 'Utiliser des objets, connaitre leur nom et leur fonction'),
    EduscolObjective(id: 'c1_v2_ps4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'PS', text: 'Réaliser une construction, fabriquer un objet librement ou par un guidage pas à pas'),
    EduscolObjective(id: 'c1_v2_ms1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'MS', text: 'Différencier des matériaux en fonction de leurs propriétés et différencier un objet du matériau qui le constitue'),
    EduscolObjective(id: 'c1_v2_ms2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'MS', text: 'Désigner et utiliser des outils ou des objets adaptés à une situation et à une action technique'),
    EduscolObjective(id: 'c1_v2_ms3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'MS', text: 'Réaliser une construction, fabriquer un objet à partir d\'un modèle'),
    EduscolObjective(id: 'c1_v2_ms4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'MS', text: 'Reproduire quelques gestes respectueux de l\'environnement montrés par l\'adulte'),
    EduscolObjective(id: 'c1_v2_gs1', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Associer une solution technique à une fonction technique'),
    EduscolObjective(id: 'c1_v2_gs2', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Fabriquer un objet en réponse à un besoin en exploitant des propriétés de matériaux ou des phénomènes physiques (équilibre, magnétisme, perméabilité, opacité ou transparence)'),
    EduscolObjective(id: 'c1_v2_gs3', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Explorer la notion de flottabilité avec des objets pleins constitués d\'une seule et même matière : observer que, plongés dans l\'eau, ils flottent tous ou coulent tous'),
    EduscolObjective(id: 'c1_v2_gs4', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Construire, fabriquer, réaliser en suivant une recette ou une fiche technique'),
    EduscolObjective(id: 'c1_v2_gs5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Élaborer une suite d\'instructions pour réaliser une tâche simple'),
    EduscolObjective(id: 'c1_v2_gs6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les objets et les matériaux', level: 'GS', text: 'Identifier et prévenir les risques liés à certains objets'),
    EduscolObjective(id: 'c1_v2_ps5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'PS', text: 'Explorer quelques caractéristiques des solides et des liquides'),
    EduscolObjective(id: 'c1_v2_ps6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'PS', text: 'Constater les effets d\'un déplacement d\'air sur des objets ou sur soi-même'),
    EduscolObjective(id: 'c1_v2_ps7', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'PS', text: 'Réaliser et observer des mélanges'),
    EduscolObjective(id: 'c1_v2_ps8', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'PS', text: 'Découvrir et observer la fusion et la solidification de l\'eau'),
    EduscolObjective(id: 'c1_v2_ms5', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'MS', text: 'Identifier une condition favorable à la fusion de la glace'),
    EduscolObjective(id: 'c1_v2_ms6', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'MS', text: 'Mettre en évidence la présence d\'air en le mettant en mouvement'),
    EduscolObjective(id: 'c1_v2_ms7', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'MS', text: 'Distinguer les solides qui se dissolvent dans l\'eau de ceux qui ne se dissolvent pas'),
    EduscolObjective(id: 'c1_v2_gs7', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'GS', text: 'Identifier et nommer l\'état de l\'eau dans différentes situations'),
    EduscolObjective(id: 'c1_v2_gs8', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'GS', text: 'Identifier la présence de l\'air quand il est perceptible par les sens'),
    EduscolObjective(id: 'c1_v2_gs9', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'GS', text: 'Distinguer, parmi quelques solides, ceux qui peuvent se dissoudre dans l\'eau'),
    EduscolObjective(id: 'c1_v2_gs10', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'GS', text: 'Commencer à agir de manière autonome pour le respect de l\'environnement'),
    EduscolObjective(id: 'c1_v2_gs11', domainId: 'd6_vivant_matiere', subdomainId: 'c1_v2', theme: 'Découvrir les états de la matière et les mélanges', level: 'GS', text: 'Prendre en compte les risques de l\'environnement familier'),
  ];
}
