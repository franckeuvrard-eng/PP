import 'dart:convert';

class ClassSettings {
  String name;
  String teacher;
  String level;
  String schoolYear;

  ClassSettings({
    required this.name,
    required this.teacher,
    required this.level,
    required this.schoolYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacher': teacher,
      'level': level,
      'schoolYear': schoolYear,
    };
  }

  factory ClassSettings.fromMap(Map<String, dynamic> map) {
    return ClassSettings(
      name: map['name'] ?? 'Classe Petite Section (PS)',
      teacher: map['teacher'] ?? 'Mme Dupont',
      level: map['level'] ?? 'PS',
      schoolYear: map['schoolYear'] ?? '2026-2027',
    );
  }

  String toJson() => json.encode(toMap());
  factory ClassSettings.fromJson(String source) => ClassSettings.fromMap(json.decode(source));
}
