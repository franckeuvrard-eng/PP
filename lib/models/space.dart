import 'dart:convert';

import 'undefined.dart';

class Space {
  final String id;
  final String name;
  final String colorHex;
  final String? description;
  final String? iconName;

  /// Ancien « mode progression » d'un espace (versions <= 1.4). Lu seulement
  /// pour la migration : un tel espace devient une Progression (cf.
  /// migrateSpaceProgressions). Toujours faux dans les donnees actuelles.
  final bool isProgression;

  /// Ancien seuil du mode progression (versions <= 1.4), repris comme
  /// Progression.minStatusId par la migration.
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
