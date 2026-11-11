import 'undefined.dart';

/// Parcours d'apprentissage : une suite ordonnee d'etapes.
///
/// Distinct d'un espace (un coin de la classe) : un atelier est toujours dans
/// un espace, une etape toujours dans un parcours. Techniquement une etape
/// est un [ActivityType] dont [ActivityType.progressionId] designe le
/// parcours (ce qui garde les observations, le scan et la synchro communs),
/// rangee par [ActivityType.position] ; elle reste verrouillee pour un eleve
/// tant que la precedente n'a pas atteint [minStatusId].
class Progression {
  final String id;
  final String name;
  final String colorHex;
  final String? iconName;
  final String? description;

  /// Niveau d'evaluation (EvaluationStatus) a atteindre sur un jalon pour
  /// debloquer le suivant. Null : le niveau « acquis » par defaut.
  final String? minStatusId;

  /// Sections qui suivent ce parcours. Vide : toute la classe.
  final List<String> targetGroups;

  /// Vrai si un eleve de cette section suit le parcours.
  bool concernsGroup(String? group) =>
      targetGroups.isEmpty || (group != null && targetGroups.contains(group));

  Progression({
    required this.id,
    required this.name,
    required this.colorHex,
    this.iconName,
    this.description,
    this.minStatusId,
    this.targetGroups = const [],
  });

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  Progression copyWith({
    String? name,
    String? colorHex,
    Object? iconName = kUndefined,
    Object? description = kUndefined,
    Object? minStatusId = kUndefined,
    List<String>? targetGroups,
  }) {
    return Progression(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName == kUndefined ? this.iconName : iconName as String?,
      description: description == kUndefined ? this.description : description as String?,
      minStatusId: minStatusId == kUndefined ? this.minStatusId : minStatusId as String?,
      targetGroups: targetGroups ?? this.targetGroups,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'iconName': iconName,
        'description': description,
        'minStatusId': minStatusId,
        'targetGroups': targetGroups,
      };

  factory Progression.fromMap(Map<String, dynamic> map) => Progression(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        colorHex: map['colorHex'] ?? '#4E9F3D',
        iconName: map['iconName'],
        description: map['description'],
        minStatusId: map['minStatusId'],
        targetGroups: List<String>.from(map['targetGroups'] ?? const []),
      );
}
