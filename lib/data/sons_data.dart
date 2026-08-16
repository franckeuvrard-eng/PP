/// Referentiel « Analyse des sons » (Langage - conscience phonemique et
/// signes graphiques), repris de la planche de suivi de Gennevilliers.
///
/// L'ordre et le contenu suivent la planche : 6 voyelles, 21 consonnes,
/// 8 sons complexes, soit 35 sons.
class SonsData {
  static const List<String> voyelles = [
    'a', 'i', 'o', 'u', 'e', 'é',
  ];

  static const List<String> consonnes = [
    'm', 's', 'f', 'l', 'b', 'j', 'p', 'r', 't', 'v', 'z',
    'c', 'd', 'g', 'h', 'k', 'n', 'q', 'w', 'x', 'y',
  ];

  static const List<String> sonsComplexes = [
    'ch', 'ai', 'ou', 'an', 'in', 'on', 'gn', 'oi',
  ];

  /// Les trois groupes dans l'ordre d'affichage.
  static const List<({String titre, List<String> sons})> groupes = [
    (titre: 'Voyelles', sons: voyelles),
    (titre: 'Consonnes', sons: consonnes),
    (titre: 'Sons complexes', sons: sonsComplexes),
  ];

  /// Les 35 sons a plat.
  static List<String> get tous => [...voyelles, ...consonnes, ...sonsComplexes];
}

/// Niveau d'acquisition d'un son. L'ordre des valeurs porte la progression :
/// un appui fait passer a l'etat suivant, et revient a [nonAcquis] apres
/// [acquis].
enum SonStatut {
  nonAcquis,
  enCours,
  acquis;

  /// Etat suivant : non acquis -> en cours -> acquis. S'arrete a [acquis],
  /// pour qu'un appui de trop ne detruise pas un pointage.
  SonStatut get suivant =>
      index >= SonStatut.values.length - 1 ? this : SonStatut.values[index + 1];

  /// Etat precedent, atteint par appui long.
  SonStatut get precedent => index <= 0 ? this : SonStatut.values[index - 1];

  String get libelle => switch (this) {
        SonStatut.nonAcquis => 'Non acquis',
        SonStatut.enCours => 'En cours',
        SonStatut.acquis => 'Acquis',
      };

  /// Valeur persistee : un entier, stable si les libelles changent.
  int get code => index;

  static SonStatut fromCode(Object? code) {
    if (code is int && code >= 0 && code < SonStatut.values.length) {
      return SonStatut.values[code];
    }
    return SonStatut.nonAcquis;
  }
}

/// Un point de l'historique d'un son pour un eleve : son statut a un instant
/// donne. Sert au graphique de progression, pas a l'etat courant (cf. table
/// `sons`, qui ne garde que la derniere valeur).
class SonHistoryEntry {
  final String son;
  final SonStatut statut;
  final DateTime changedAt;

  const SonHistoryEntry({
    required this.son,
    required this.statut,
    required this.changedAt,
  });
}
