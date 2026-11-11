/// Saisies de l'enseignant pour le carnet de suivi d'un eleve : un
/// enregistrement par periode (commentaire par domaine), et un pour la
/// synthese des acquis de fin d'ecole maternelle (niveau par sous-domaine,
/// points forts, besoins).
class CarnetEntry {
  /// `<childId>|<periode>` : une seule saisie par eleve et par periode.
  final String id;
  final String childId;

  /// Periode : `P1` a `P5` (annee en cours), ou [synthese].
  final String period;

  /// Commentaire par domaine (EduscolDomain.id).
  final Map<String, String> comments;

  /// Synthese : niveau par sous-domaine (EduscolSubdomain.id) -> [levels].
  final Map<String, String> levels;

  final String strengths;
  final String needs;
  final DateTime updatedAt;

  static const synthese = 'synthese';

  /// Les trois niveaux de la synthese officielle.
  static const levelNotYet = 'pas_encore';
  static const levelOnTheWay = 'en_voie';
  static const levelOften = 'souvent';
  static const levelLabels = {
    levelNotYet: 'Ne réussit pas encore',
    levelOnTheWay: 'Est en voie de réussite',
    levelOften: 'Réussit souvent',
  };

  static String idFor(String childId, String period) => '$childId|$period';

  CarnetEntry({
    required this.childId,
    required this.period,
    this.comments = const {},
    this.levels = const {},
    this.strengths = '',
    this.needs = '',
    DateTime? updatedAt,
  })  : id = idFor(childId, period),
        updatedAt = updatedAt ?? DateTime.now();

  CarnetEntry copyWith({
    Map<String, String>? comments,
    Map<String, String>? levels,
    String? strengths,
    String? needs,
  }) =>
      CarnetEntry(
        childId: childId,
        period: period,
        comments: comments ?? this.comments,
        levels: levels ?? this.levels,
        strengths: strengths ?? this.strengths,
        needs: needs ?? this.needs,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'period': period,
        'comments': comments,
        'levels': levels,
        'strengths': strengths,
        'needs': needs,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CarnetEntry.fromMap(Map<String, dynamic> map) => CarnetEntry(
        childId: map['childId'] ?? '',
        period: map['period'] ?? '',
        comments: Map<String, String>.from(map['comments'] ?? const {}),
        levels: Map<String, String>.from(map['levels'] ?? const {}),
        strengths: map['strengths'] ?? '',
        needs: map['needs'] ?? '',
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? ''),
      );
}
