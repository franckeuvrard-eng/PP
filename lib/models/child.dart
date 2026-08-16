import 'dart:convert';

import 'undefined.dart';

class Child {
  final String id;
  final String firstname;
  final String? lastname;
  final String? birthdate;
  final String? group;
  final String? notes;
  final String colorHex;
  final String avatarText;
  final String? email;
  final String? imagePath;

  /// Autorisation « droit à l'image » donnée par les parents pour les photos.
  ///
  /// Faux par defaut a la creation : c'est a l'enseignant de la cocher une
  /// fois l'autorisation effectivement recueillie, plutot que de supposer un
  /// accord implicite.
  final bool imageAuthorized;

  Child({
    required this.id,
    required this.firstname,
    this.lastname,
    this.birthdate,
    this.group,
    this.notes,
    required this.colorHex,
    required this.avatarText,
    this.email,
    this.imagePath,
    this.imageAuthorized = false,
  });

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  Child copyWith({
    String? id,
    String? firstname,
    Object? lastname = kUndefined,
    Object? birthdate = kUndefined,
    Object? group = kUndefined,
    Object? notes = kUndefined,
    String? colorHex,
    String? avatarText,
    Object? email = kUndefined,
    Object? imagePath = kUndefined,
    bool? imageAuthorized,
  }) {
    return Child(
      id: id ?? this.id,
      firstname: firstname ?? this.firstname,
      lastname: lastname == kUndefined ? this.lastname : lastname as String?,
      birthdate: birthdate == kUndefined ? this.birthdate : birthdate as String?,
      group: group == kUndefined ? this.group : group as String?,
      notes: notes == kUndefined ? this.notes : notes as String?,
      colorHex: colorHex ?? this.colorHex,
      avatarText: avatarText ?? this.avatarText,
      email: email == kUndefined ? this.email : email as String?,
      imagePath: imagePath == kUndefined ? this.imagePath : imagePath as String?,
      imageAuthorized: imageAuthorized ?? this.imageAuthorized,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'birthdate': birthdate,
      'group': group,
      'notes': notes,
      'colorHex': colorHex,
      'avatarText': avatarText,
      'email': email,
      'imagePath': imagePath,
      'imageAuthorized': imageAuthorized,
    };
  }

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'] ?? '',
      firstname: map['firstname'] ?? '',
      lastname: map['lastname'],
      birthdate: map['birthdate'],
      group: map['group'],
      notes: map['notes'],
      colorHex: map['colorHex'] ?? '#4E9F3D',
      avatarText: map['avatarText'] ?? (map['firstname'] != null && map['firstname'].isNotEmpty ? map['firstname'][0] : 'E'),
      email: map['email'],
      imagePath: map['imagePath'],
      // Absent = fiche creee avant cette fonctionnalite : on ne bloque pas
      // retroactivement des photos deja en usage. Present mais faux = choix
      // explicite de l'enseignant, respecte tel quel.
      imageAuthorized: map.containsKey('imageAuthorized') ? (map['imageAuthorized'] ?? false) : true,
    );
  }

  String toJson() => json.encode(toMap());
  factory Child.fromJson(String source) => Child.fromMap(json.decode(source));
}
