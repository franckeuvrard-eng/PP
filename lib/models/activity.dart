import 'dart:convert';

class ActivityLog {
  final String id;
  final String childId;
  final String activityTypeId;
  final DateTime timestamp;
  final String? note;
  final List<String> photoPaths;
  final String? evaluationStatus;

  /// Legende de chaque photo, indexee par chemin plutot que par position :
  /// supprimer une photo ne decale alors pas les commentaires des suivantes.
  final Map<String, String> photoCaptions;

  ActivityLog({
    required this.id,
    required this.childId,
    required this.activityTypeId,
    required this.timestamp,
    this.note,
    this.photoPaths = const [],
    this.evaluationStatus,
    this.photoCaptions = const {},
  });

  /// Legende associee a une photo, ou null si aucune.
  String? captionFor(String path) {
    final caption = photoCaptions[path];
    if (caption == null || caption.trim().isEmpty) return null;
    return caption.trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'activityTypeId': activityTypeId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'photoPaths': photoPaths,
      'evaluationStatus': evaluationStatus,
      'photoCaptions': photoCaptions,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      childId: map['childId'] ?? '',
      activityTypeId: map['activityTypeId'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      note: map['note'],
      photoPaths: List<String>.from(map['photoPaths'] ?? []),
      evaluationStatus: map['evaluationStatus'],
      photoCaptions: Map<String, String>.from(map['photoCaptions'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityLog.fromJson(String source) => ActivityLog.fromMap(json.decode(source));
}
