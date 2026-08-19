import 'dart:convert';

import 'undefined.dart';

class Space {
  final String id;
  final String name;
  final String colorHex;
  final String? description;
  final String? iconName;

  /// Vrai si les ateliers de cet espace doivent etre faits dans l'ordre
  /// (voir [ActivityType.position]) : un atelier reste verrouille tant que
  /// les precedents n'ont pas atteint [progressionMinStatusId] chez l'eleve.
  final bool isProgression;

  /// Identifiant du niveau d'evaluation minimum (voir EvaluationStatus) a
  /// atteindre sur un atelier pour debloquer le suivant. Null tant que le
  /// mode progression n'a jamais ete configure sur cet espace.
  final String? progressionMinStatusId;

  Space({
    required this.id,
    required this.name,
    required this.colorHex,
    this.description,
    this.iconName,
    this.isProgression = false,
    this.progressionMinStatusId,
  });

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  Space copyWith({
    String? id,
    String? name,
    String? colorHex,
    Object? description = kUndefined,
    Object? iconName = kUndefined,
    bool? isProgression,
    Object? progressionMinStatusId = kUndefined,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      description: description == kUndefined ? this.description : description as String?,
      iconName: iconName == kUndefined ? this.iconName : iconName as String?,
      isProgression: isProgression ?? this.isProgression,
      progressionMinStatusId: progressionMinStatusId == kUndefined
          ? this.progressionMinStatusId
          : progressionMinStatusId as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'description': description,
      'iconName': iconName,
      'isProgression': isProgression,
      'progressionMinStatusId': progressionMinStatusId,
    };
  }

  factory Space.fromMap(Map<String, dynamic> map) {
    return Space(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? '#4E9F3D',
      description: map['description'],
      iconName: map['iconName'],
      isProgression: map['isProgression'] ?? false,
      progressionMinStatusId: map['progressionMinStatusId'],
    );
  }

  String toJson() => json.encode(toMap());
  factory Space.fromJson(String source) => Space.fromMap(json.decode(source));
}
