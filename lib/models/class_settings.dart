import 'dart:convert';

import 'undefined.dart';

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

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  ClassSettings copyWith({
    String? name,
    String? teacher,
    Object? atsem = kUndefined,
    Object? schoolName = kUndefined,
    String? level,
    String? schoolYear,
    Object? logoPath = kUndefined,
  }) {
    return ClassSettings(
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      atsem: atsem == kUndefined ? this.atsem : atsem as String?,
      schoolName: schoolName == kUndefined ? this.schoolName : schoolName as String?,
      level: level ?? this.level,
      schoolYear: schoolYear ?? this.schoolYear,
      logoPath: logoPath == kUndefined ? this.logoPath : logoPath as String?,
    );
  }

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
