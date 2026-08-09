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

  ActivityType({
    required this.id,
    required this.name,
    required this.spaceId,
    required this.colorHex,
    this.description,
    this.imagePath,
    this.domaine = '',
    this.objectifs = const [],
  });

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
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityType.fromJson(String source) => ActivityType.fromMap(json.decode(source));
}
