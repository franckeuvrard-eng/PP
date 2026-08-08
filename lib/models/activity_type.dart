import 'dart:convert';

class ActivityType {
  final String id;
  final String name;
  final String category;
  final String iconName;
  final String colorHex;
  final String? description;
  final String? imagePath;
  final List<String> pedagogicalDomains;

  ActivityType({
    required this.id,
    required this.name,
    required this.category,
    required this.iconName,
    required this.colorHex,
    this.description,
    this.imagePath,
    this.pedagogicalDomains = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'iconName': iconName,
      'colorHex': colorHex,
      'description': description,
      'imagePath': imagePath,
      'pedagogicalDomains': pedagogicalDomains,
    };
  }

  factory ActivityType.fromMap(Map<String, dynamic> map) {
    return ActivityType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'Général',
      iconName: map['iconName'] ?? 'palette',
      colorHex: map['colorHex'] ?? '#FF7043',
      description: map['description'],
      imagePath: map['imagePath'],
      pedagogicalDomains: List<String>.from(map['pedagogicalDomains'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityType.fromJson(String source) => ActivityType.fromMap(json.decode(source));
}
