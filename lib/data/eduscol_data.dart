class EduscolDomain {
  final String id;
  final String title;
  final String iconName;
  final String colorHex;

  const EduscolDomain({
    required this.id,
    required this.title,
    required this.iconName,
    required this.colorHex,
  });
}

class EduscolObjective {
  final String id;
  final String domainId;
  final String level; // 'PS', 'MS', 'GS', 'Tous'
  final String text;

  const EduscolObjective({
    required this.id,
    required this.domainId,
    required this.level,
    required this.text,
  });
}

class EduscolData {
  static const List<EduscolDomain> domains = [
    EduscolDomain(
      id: 'd1_langage',
      title: 'Mobiliser le langage dans toutes ses dimensions',
      iconName: 'record_voice_over',
      colorHex: '#FF7043',
    ),
    EduscolDomain(
      id: 'd2_maths',
      title: 'Acquérir les premiers outils mathématiques',
      iconName: 'calculate',
      colorHex: '#4E9F3D',
    ),
    EduscolDomain(
      id: 'd3_physique',
      title: 'Agir, s\'exprimer, comprendre à travers l\'activité physique',
      iconName: 'directions_run',
      colorHex: '#7E57C2',
    ),
    EduscolDomain(
      id: 'd4_art',
      title: 'Agir, s\'exprimer, comprendre à travers les activités artistiques',
      iconName: 'palette',
      colorHex: '#E91E63',
    ),
    EduscolDomain(
      id: 'd5_monde',
      title: 'Explorer le monde',
      iconName: 'public',
      colorHex: '#00BCD4',
    ),
  ];

  static const List<EduscolObjective> objectives = [
    // DOMAINE 1 : MOBILISER LE LANGAGE
    // PS (2-4 ans)
    EduscolObjective(id: 'l_ps_1', domainId: 'd1_langage', level: 'PS', text: 'S\'exprimer par des mots-phrases ou des phrases simples'),
    EduscolObjective(id: 'l_ps_2', domainId: 'd1_langage', level: 'PS', text: 'Comprendre des consignes simples de la vie de classe'),
    EduscolObjective(id: 'l_ps_3', domainId: 'd1_langage', level: 'PS', text: 'Écouter attentivement une histoire courte lue par l\'adulte'),
    EduscolObjective(id: 'l_ps_4', domainId: 'd1_langage', level: 'PS', text: 'Répéter des comptines et jeux de doigts simples'),
    EduscolObjective(id: 'l_ps_5', domainId: 'd1_langage', level: 'PS', text: 'Reconnaître son prénom avec son initiale ou sa photo'),
    EduscolObjective(id: 'l_ps_6', domainId: 'd1_langage', level: 'PS', text: 'Manipuler des livres avec soin et tourner les pages'),
    EduscolObjective(id: 'l_ps_7', domainId: 'd1_langage', level: 'PS', text: 'Réaliser des tracés libres (gribouillages, lignes, ronds)'),

    // MS (4-5 ans)
    EduscolObjective(id: 'l_ms_1', domainId: 'd1_langage', level: 'MS', text: 'S\'exprimer dans un langage syntaxiquement correct'),
    EduscolObjective(id: 'l_ms_2', domainId: 'd1_langage', level: 'MS', text: 'Reformuler l\'histoire lue avec ses propres mots'),
    EduscolObjective(id: 'l_ms_3', domainId: 'd1_langage', level: 'MS', text: 'Scander les syllabes d\'un mot (frapper dans les mains)'),
    EduscolObjective(id: 'l_ms_4', domainId: 'd1_langage', level: 'MS', text: 'Distinguer des rimes et assonances simples'),
    EduscolObjective(id: 'l_ms_5', domainId: 'd1_langage', level: 'MS', text: 'Reconnaître son prénom en lettres capitales d\'imprimerie'),
    EduscolObjective(id: 'l_ms_6', domainId: 'd1_langage', level: 'MS', text: 'Reproduire des motifs graphiques (lignes verticales, horizontales, quadrillages)'),
    EduscolObjective(id: 'l_ms_7', domainId: 'd1_langage', level: 'MS', text: 'Tenir correctement son outil scripteur (pince des doigts)'),

    // GS (5-6 ans)
    EduscolObjective(id: 'l_gs_1', domainId: 'd1_langage', level: 'GS', text: 'Prendre la parole dans un groupe pour donner son avis'),
    EduscolObjective(id: 'l_gs_2', domainId: 'd1_langage', level: 'GS', text: 'Comprendre une histoire complexe et expliquer les intentions des personnages'),
    EduscolObjective(id: 'l_gs_3', domainId: 'd1_langage', level: 'GS', text: 'Isoler les syllabes et les phonèmes dans les mots'),
    EduscolObjective(id: 'l_gs_4', domainId: 'd1_langage', level: 'GS', text: 'Connaître le nom de la plupart des lettres de l\'alphabet'),
    EduscolObjective(id: 'l_gs_5', domainId: 'd1_langage', level: 'GS', text: 'Faire la correspondance entre lettres capitales et scriptes'),
    EduscolObjective(id: 'l_gs_6', domainId: 'd1_langage', level: 'GS', text: 'Écrire son prénom en écriture cursive sans modèle'),
    EduscolObjective(id: 'l_gs_7', domainId: 'd1_langage', level: 'GS', text: 'Encoder des mots simples en s\'appuyant sur les sons (Phonologie)'),

    // DOMAINE 2 : OUTILS MATHEMATIQUES
    // PS (2-4 ans)
    EduscolObjective(id: 'm_ps_1', domainId: 'd2_maths', level: 'PS', text: 'Dénombrer une quantité de 1 à 3 objets'),
    EduscolObjective(id: 'm_ps_2', domainId: 'd2_maths', level: 'PS', text: 'Constituer une collection ayant autant d\'objets qu\'une autre (jusqu\'à 3)'),
    EduscolObjective(id: 'm_ps_3', domainId: 'd2_maths', level: 'PS', text: 'Trier et classer des objets selon un critère (couleur, forme, taille)'),
    EduscolObjective(id: 'm_ps_4', domainId: 'd2_maths', level: 'PS', text: 'Reconnaître les formes simples : cercle, carré'),
    EduscolObjective(id: 'm_ps_5', domainId: 'd2_maths', level: 'PS', text: 'Réaliser un encastrement ou puzzle de 4 à 8 pièces'),

    // MS (4-5 ans)
    EduscolObjective(id: 'm_ms_1', domainId: 'd2_maths', level: 'MS', text: 'Dénombrer une quantité jusqu\'à 5 ou 6 objets'),
    EduscolObjective(id: 'm_ms_2', domainId: 'd2_maths', level: 'MS', text: 'Reconnaître les chiffres de 1 à 6'),
    EduscolObjective(id: 'm_ms_3', domainId: 'd2_maths', level: 'MS', text: 'Comparer deux collections (plus que, moins que, autant)'),
    EduscolObjective(id: 'm_ms_4', domainId: 'd2_maths', level: 'MS', text: 'Poursuivre un algorithme simple (ex: rouge/bleu/rouge/bleu)'),
    EduscolObjective(id: 'm_ms_5', domainId: 'd2_maths', level: 'MS', text: 'Reconnaître et nommer triangle, carré, cercle, rectangle'),
    EduscolObjective(id: 'm_ms_6', domainId: 'd2_maths', level: 'MS', text: 'Réaliser un puzzle de 12 à 24 pièces'),

    // GS (5-6 ans)
    EduscolObjective(id: 'm_gs_1', domainId: 'd2_maths', level: 'GS', text: 'Dénombrer jusqu\'à 10 objets et plus'),
    EduscolObjective(id: 'm_gs_2', domainId: 'd2_maths', level: 'GS', text: 'Associer le nom des nombres à leur écriture chiffrée jusqu\'à 10'),
    EduscolObjective(id: 'm_gs_3', domainId: 'd2_maths', level: 'GS', text: 'Résoudre des problèmes simples d\'ajout ou de retrait'),
    EduscolObjective(id: 'm_gs_4', domainId: 'd2_maths', level: 'GS', text: 'Ranger des objets selon leur taille, leur longueur ou leur masse'),
    EduscolObjective(id: 'm_gs_5', domainId: 'd2_maths', level: 'GS', text: 'Se repérer et se déplacer sur un quadrillage'),
    EduscolObjective(id: 'm_gs_6', domainId: 'd2_maths', level: 'GS', text: 'Reconnaître des solides simples (cube, pyramide, boule)'),

    // DOMAINE 3 : ACTIVITE PHYSIQUE
    // PS (2-4 ans)
    EduscolObjective(id: 'p_ps_1', domainId: 'd3_physique', level: 'PS', text: 'Courir, sauter, lancer dans un espace aménagé'),
    EduscolObjective(id: 'p_ps_2', domainId: 'd3_physique', level: 'PS', text: 'Garder l\'équilibre sur des poutres ou modules de motricité'),
    EduscolObjective(id: 'p_ps_3', domainId: 'd3_physique', level: 'PS', text: 'Accepter de jouer avec ses camarades'),

    // MS (4-5 ans)
    EduscolObjective(id: 'p_ms_1', domainId: 'd3_physique', level: 'MS', text: 'Ajuster son geste (sauter plus loin, lancer avec précision)'),
    EduscolObjective(id: 'p_ms_2', domainId: 'd3_physique', level: 'MS', text: 'Coopérer avec un partenaire dans un jeu collectif'),
    EduscolObjective(id: 'p_ms_3', domainId: 'd3_physique', level: 'MS', text: 'Suivre un rythme corporel en musique ou en ronde'),

    // GS (5-6 ans)
    EduscolObjective(id: 'p_gs_1', domainId: 'd3_physique', level: 'GS', text: 'Respecter les règles élaborées dans un jeu collectif'),
    EduscolObjective(id: 'p_gs_2', domainId: 'd3_physique', level: 'GS', text: 'Enchaîner plusieurs actions motrices (courir puis sauter)'),
    EduscolObjective(id: 'p_gs_3', domainId: 'd3_physique', level: 'GS', text: 'Exprimer des intentions par le corps dans une danse'),

    // DOMAINE 4 : ACTIVITES ARTISTIQUES
    // PS (2-4 ans)
    EduscolObjective(id: 'a_ps_1', domainId: 'd4_art', level: 'PS', text: 'Manipuler la peinture avec les doigts, pinceaux, tampons'),
    EduscolObjective(id: 'a_ps_2', domainId: 'd4_art', level: 'PS', text: 'Explorer la matière (pâte à modeler, pâte à sel, sable)'),
    EduscolObjective(id: 'a_ps_3', domainId: 'd4_art', level: 'PS', text: 'Chanter en groupe des comptines simples à gestes'),

    // MS (4-5 ans)
    EduscolObjective(id: 'a_ms_1', domainId: 'd4_art', level: 'MS', text: 'Combiner plusieurs outils et techniques plastiques (découpage, collage)'),
    EduscolObjective(id: 'a_ms_2', domainId: 'd4_art', level: 'MS', text: 'Réaliser une composition en volume (assemblage)'),
    EduscolObjective(id: 'a_ms_3', domainId: 'd4_art', level: 'MS', text: 'Mémoriser et chanter avec justesse un répertoire de chansons'),

    // GS (5-6 ans)
    EduscolObjective(id: 'a_gs_1', domainId: 'd4_art', level: 'GS', text: 'Exprimer une émotion à travers une réalisation plastique personnelle'),
    EduscolObjective(id: 'a_gs_2', domainId: 'd4_art', level: 'GS', text: 'Créer une œuvre collective en s\'inspirant d\'un artiste'),
    EduscolObjective(id: 'a_gs_3', domainId: 'd4_art', level: 'GS', text: 'Reconnaître et distinguer les sons d\'instruments de musique simples'),

    // DOMAINE 5 : EXPLORER LE MONDE
    // PS (2-4 ans)
    EduscolObjective(id: 'e_ps_1', domainId: 'd5_monde', level: 'PS', text: 'Se repérer dans les moments de la journée de classe (matin, cantine, sieste, après-midi)'),
    EduscolObjective(id: 'e_ps_2', domainId: 'd5_monde', level: 'PS', text: 'Nommer les principales parties du corps humain'),
    EduscolObjective(id: 'e_ps_3', domainId: 'd5_monde', level: 'PS', text: 'Manipuler de l\'eau, du sable et observer leurs transformations'),

    // MS (4-5 ans)
    EduscolObjective(id: 'e_ms_1', domainId: 'd5_monde', level: 'MS', text: 'Se repérer dans la semaine à l\'aide du calendrier des jours'),
    EduscolObjective(id: 'e_ms_2', domainId: 'd5_monde', level: 'MS', text: 'Observer le vivant (croissance des plantes, élevage d\'animaux)'),
    EduscolObjective(id: 'e_ms_3', domainId: 'd5_monde', level: 'MS', text: 'Classer les objets selon leurs caractéristiques (lourd/léger, chaud/froid)'),

    // GS (5-6 ans)
    EduscolObjective(id: 'e_gs_1', domainId: 'd5_monde', level: 'GS', text: 'Comprendre la succession des mois et des saisons'),
    EduscolObjective(id: 'e_gs_2', domainId: 'd5_monde', level: 'GS', text: 'Comprendre le cycle de la vie (naissance, croissance, reproduction)'),
    EduscolObjective(id: 'e_gs_3', domainId: 'd5_monde', level: 'GS', text: 'Fabriquer ou construire un objet selon une fiche ou maquette'),
  ];
}
