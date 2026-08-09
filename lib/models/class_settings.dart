import 'dart:convert';

class ClassSettings {
  String name;
  String teacher;
  String? atsem;
  String? schoolName;
  String level;
  String schoolYear;
  String? logoPath;

  ClassSettings({
    required this.name,
    required this.teacher,
    this.atsem,
    this.schoolName,
    required this.level,
    required this.schoolYear,
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacher': teacher,
      'atsem': atsem,
      'schoolName': schoolName,
      'level': level,
      'schoolYear': schoolYear,
      'logoPath': logoPath,
    };
  }

  factory ClassSettings.fromMap(Map<String, dynamic> map) {
    return ClassSettings(
      name: map['name'] ?? 'Classe Petite Section (PS)',
      teacher: map['teacher'] ?? 'Mme Dupont',
      atsem: map['atsem'],
      schoolName: map['schoolName'],
      level: map['level'] ?? 'PS',
      schoolYear: map['schoolYear'] ?? '2026-2027',
      logoPath: map['logoPath'],
    );
  }

  String toJson() => json.encode(toMap());
  factory ClassSettings.fromJson(String source) => ClassSettings.fromMap(json.decode(source));
}
