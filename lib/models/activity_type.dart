import 'dart:convert';

class ActivityType {
  final String id;
  final String name;
  final String category;
  final String iconName;
  final String colorHex;

  ActivityType({
    required this.id,
    required this.name,
    required this.category,
    required this.iconName,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'iconName': iconName,
      'colorHex': colorHex,
    };
  }

  factory ActivityType.fromMap(Map<String, dynamic> map) {
    return ActivityType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'Général',
      iconName: map['iconName'] ?? 'palette',
      colorHex: map['colorHex'] ?? '#FF7043',
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityType.fromJson(String source) => ActivityType.fromMap(json.decode(source));
}
