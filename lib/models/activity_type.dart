import 'dart:convert';

import 'undefined.dart';

class ActivityType {
  final String id;
  final String name;
  final String spaceId;
  final String colorHex;
  final String? description;
  final String? imagePath;
  /// Libellé du domaine. Reste la source pour un domaine personnalisé.
  final String domaine;

  /// Identifiant du domaine Éduscol (voir EduscolData.domains), ou null pour
  /// un domaine saisi librement.
  ///
  /// Le libellé seul liait l'atelier au texte exact du référentiel : le jour où
  /// une formulation officielle évolue, l'atelier se retrouverait rattaché à
  /// un domaine qui n'existe plus.
  final String? domaineId;
  final List<String> objectifs;
  final bool isObligatory;

  /// Cle du catalogue AppIcons (voir lib/utils/app_icons.dart).
  final String? iconName;

  /// Photos d'illustration de l'atelier (chemins relatifs au dossier Documents).
  final List<String> photoPaths;

  /// Legende de chaque photo, indexee par chemin relatif.
  ///
  /// Une Map plutot qu'une liste parallele : supprimer une photo ne decale
  /// alors pas les commentaires des suivantes.
  final Map<String, String> photoCaptions;

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
    this.domaineId,
    this.objectifs = const [],
    this.isObligatory = false,
    this.iconName,
    this.photoPaths = const [],
    this.photoCaptions = const {},
    this.obligatoryGroups = const [],
  });

  /// Legende associee a une photo, ou null si aucune.
  String? captionFor(String relPath) {
    final caption = photoCaptions[relPath];
    if (caption == null || caption.trim().isEmpty) return null;
    return caption.trim();
  }

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

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  ActivityType copyWith({
    String? id,
    String? name,
    String? spaceId,
    String? colorHex,
    Object? description = kUndefined,
    Object? imagePath = kUndefined,
    String? domaine,
    Object? domaineId = kUndefined,
    List<String>? objectifs,
    bool? isObligatory,
    Object? iconName = kUndefined,
    List<String>? photoPaths,
    Map<String, String>? photoCaptions,
    List<String>? obligatoryGroups,
  }) {
    return ActivityType(
      id: id ?? this.id,
      name: name ?? this.name,
      spaceId: spaceId ?? this.spaceId,
      colorHex: colorHex ?? this.colorHex,
      description: description == kUndefined ? this.description : description as String?,
      imagePath: imagePath == kUndefined ? this.imagePath : imagePath as String?,
      domaine: domaine ?? this.domaine,
      domaineId: domaineId == kUndefined ? this.domaineId : domaineId as String?,
      objectifs: objectifs ?? this.objectifs,
      isObligatory: isObligatory ?? this.isObligatory,
      iconName: iconName == kUndefined ? this.iconName : iconName as String?,
      photoPaths: photoPaths ?? this.photoPaths,
      photoCaptions: photoCaptions ?? this.photoCaptions,
      obligatoryGroups: obligatoryGroups ?? this.obligatoryGroups,
    );
  }

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
      'domaineId': domaineId,
      'objectifs': objectifs,
      'isObligatory': isObligatory,
      'iconName': iconName,
      'photoPaths': photoPaths,
      'photoCaptions': photoCaptions,
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
      domaineId: map['domaineId'],
      objectifs: List<String>.from(map['objectifs'] ?? map['pedagogicalDomains'] ?? []),
      isObligatory: map['isObligatory'] ?? false,
      iconName: map['iconName'],
      photoPaths: List<String>.from(map['photoPaths'] ?? []),
      photoCaptions: Map<String, String>.from(map['photoCaptions'] ?? {}),
      obligatoryGroups: List<String>.from(map['obligatoryGroups'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityType.fromJson(String source) => ActivityType.fromMap(json.decode(source));
}
