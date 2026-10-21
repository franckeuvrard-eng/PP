import 'undefined.dart';

/// Parcours d'apprentissage : une suite ordonnee d'ateliers (les jalons).
///
/// Distincte d'un espace (un coin de la classe) : un atelier appartient soit
/// a un espace, soit a une progression ([ActivityType.progressionId]), jamais
/// aux deux. Les jalons sont les ateliers de la progression, ranges par
/// [ActivityType.position] ; un jalon reste verrouille pour un eleve tant que
/// le precedent n'a pas atteint [minStatusId].
class Progression {
  final String id;
  final String name;
  final String colorHex;
  final String? iconName;
  final String? description;

  /// Niveau d'evaluation (EvaluationStatus) a atteindre sur un jalon pour
  /// debloquer le suivant. Null : le niveau « acquis » par defaut.
  final String? minStatusId;

  Progression({
    required this.id,
    required this.name,
    required this.colorHex,
    this.iconName,
    this.description,
    this.minStatusId,
  });

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  Progression copyWith({
    String? name,
    String? colorHex,
    Object? iconName = kUndefined,
    Object? description = kUndefined,
    Object? minStatusId = kUndefined,
  }) {
    return Progression(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName == kUndefined ? this.iconName : iconName as String?,
      description: description == kUndefined ? this.description : description as String?,
      minStatusId: minStatusId == kUndefined ? this.minStatusId : minStatusId as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'iconName': iconName,
        'description': description,
        'minStatusId': minStatusId,
      };

  factory Progression.fromMap(Map<String, dynamic> map) => Progression(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        colorHex: map['colorHex'] ?? '#4E9F3D',
        iconName: map['iconName'],
        description: map['description'],
        minStatusId: map['minStatusId'],
      );
}
