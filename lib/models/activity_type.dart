import 'dart:convert';

class ActivityType {
  final String id;
  final String name;
  final String spaceId;
  final String colorHex;
  final String? description;
  final String? imagePath;
  final String domaine;
  final List<String> objectifs;
  final bool isObligatory;

  /// Cle du catalogue AppIcons (voir lib/utils/app_icons.dart).
  final String? iconName;

  /// Photos d'illustration de l'atelier (chemins relatifs au dossier Documents).
  final List<String> photoPaths;

  /// Groupes / sections pour lesquels l'atelier est obligatoire.
  /// Vide alors que [isObligatory] est vrai : obligatoire pour toute la classe.
  final List<String> obligatoryGroups;

  ActivityType({
    required this.id,
    required this.name,
    required this.spaceId,
    required this.colorHex,
    this.description,
    this.imagePath,
    this.domaine = '',
    this.objectifs = const [],
    this.isObligatory = false,
    this.iconName,
    this.photoPaths = const [],
    this.obligatoryGroups = const [],
  });

  /// Vrai si l'atelier est obligatoire pour un eleve de ce groupe.
  ///
  /// Sans ciblage, l'obligation vaut pour toute la classe : c'est le
  /// comportement des ateliers crees avant l'ajout de [obligatoryGroups].
  bool isObligatoryForGroup(String? group) {
    if (!isObligatory) return false;
    if (obligatoryGroups.isEmpty) return true;
    return group != null && obligatoryGroups.contains(group);
  }

  /// Toutes les photos de l'atelier, l'illustration principale en tete.
  List<String> get allPhotoPaths => [
        if (imagePath != null && imagePath!.isNotEmpty) imagePath!,
        ...photoPaths,
      ];

  // Backwards compatibility: map old 'category' field to 'spaceId'
  // and old 'pedagogicalDomains' to 'objectifs'
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'spaceId': spaceId,
      'colorHex': colorHex,
      'description': description,
      'imagePath': imagePath,
      'domaine': domaine,
      'objectifs': objectifs,
      'isObligatory': isObligatory,
      'iconName': iconName,
      'photoPaths': photoPaths,
      'obligatoryGroups': obligatoryGroups,
    };
  }

  factory ActivityType.fromMap(Map<String, dynamic> map) {
    return ActivityType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      spaceId: map['spaceId'] ?? map['category'] ?? '',
      colorHex: map['colorHex'] ?? '#FF7043',
      description: map['description'],
      imagePath: map['imagePath'],
      domaine: map['domaine'] ?? '',
      objectifs: List<String>.from(map['objectifs'] ?? map['pedagogicalDomains'] ?? []),
      isObligatory: map['isObligatory'] ?? false,
      iconName: map['iconName'],
      photoPaths: List<String>.from(map['photoPaths'] ?? []),
      obligatoryGroups: List<String>.from(map['obligatoryGroups'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityType.fromJson(String source) => ActivityType.fromMap(json.decode(source));
}
