import 'dart:convert';

/// Trace d'une annee scolaire archivee puis effacee de la classe en cours.
///
/// L'archive elle-meme est un ZIP pose dans `Documents/archives/` : cet objet
/// n'en garde que la fiche signaletique, pour que les reglages puissent lister
/// les annees precedentes et les repartager sans rouvrir chaque fichier.
class SchoolYearArchive {
  final String id;

  /// Annee archivee, telle qu'elle etait saisie dans les reglages de classe.
  final String schoolYear;
  final DateTime createdAt;

  /// Nom du fichier dans `Documents/archives/`, sans le chemin : le repertoire
  /// des documents change d'identifiant a chaque reinstallation sur iOS, un
  /// chemin absolu stocke ici deviendrait faux.
  final String fileName;

  final int childCount;
  final int activityCount;
  final int sizeBytes;

  SchoolYearArchive({
    required this.id,
    required this.schoolYear,
    required this.createdAt,
    required this.fileName,
    required this.childCount,
    required this.activityCount,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolYear': schoolYear,
        'createdAt': createdAt.toIso8601String(),
        'fileName': fileName,
        'childCount': childCount,
        'activityCount': activityCount,
        'sizeBytes': sizeBytes,
      };

  factory SchoolYearArchive.fromMap(Map<String, dynamic> map) => SchoolYearArchive(
        id: map['id'] ?? '',
        schoolYear: map['schoolYear'] ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime(1970),
        fileName: map['fileName'] ?? '',
        childCount: (map['childCount'] as num?)?.toInt() ?? 0,
        activityCount: (map['activityCount'] as num?)?.toInt() ?? 0,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      );

  String toJson() => json.encode(toMap());
  factory SchoolYearArchive.fromJson(String source) =>
      SchoolYearArchive.fromMap(json.decode(source));
}
