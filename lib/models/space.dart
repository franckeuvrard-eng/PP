import 'dart:convert';

class Space {
  final String id;
  final String name;
  final String colorHex;
  final String? description;
  final String? iconName;

  Space({
    required this.id,
    required this.name,
    required this.colorHex,
    this.description,
    this.iconName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'description': description,
      'iconName': iconName,
    };
  }

  factory Space.fromMap(Map<String, dynamic> map) {
    return Space(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? '#4E9F3D',
      description: map['description'],
      iconName: map['iconName'],
    );
  }

  String toJson() => json.encode(toMap());
  factory Space.fromJson(String source) => Space.fromMap(json.decode(source));
}
