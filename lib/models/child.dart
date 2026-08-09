import 'dart:convert';

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
  });

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
    );
  }

  String toJson() => json.encode(toMap());
  factory Child.fromJson(String source) => Child.fromMap(json.decode(source));
}
