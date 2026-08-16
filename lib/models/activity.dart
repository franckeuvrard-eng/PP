import 'dart:convert';

import 'undefined.dart';

class ActivityLog {
  final String id;
  final String childId;
  final String activityTypeId;
  final DateTime timestamp;
  final String? note;
  final List<String> photoPaths;
  /// Identifiant du niveau d'évaluation (voir EvaluationStatus).
  final String? evaluationStatusId;

  /// Libellé hérité des versions antérieures aux identifiants stables.
  ///
  /// Lu uniquement par la migration au démarrage, qui le convertit en
  /// identifiant. Les nouvelles observations ne l'écrivent pas.
  final String? legacyStatusLabel;

  /// Legende de chaque photo, indexee par chemin plutot que par position :
  /// supprimer une photo ne decale alors pas les commentaires des suivantes.
  final Map<String, String> photoCaptions;

  /// Chemin relatif d'une note vocale unique jointe a l'observation.
  final String? audioPath;

  ActivityLog({
    required this.id,
    required this.childId,
    required this.activityTypeId,
    required this.timestamp,
    this.note,
    this.photoPaths = const [],
    this.evaluationStatusId,
    this.legacyStatusLabel,
    this.photoCaptions = const {},
    this.audioPath,
  });

  /// Legende associee a une photo, ou null si aucune.
  String? captionFor(String path) {
    final caption = photoCaptions[path];
    if (caption == null || caption.trim().isEmpty) return null;
    return caption.trim();
  }

  /// Copie modifiee. Les champs non fournis restent inchanges ; passer
  /// explicitement `null` a un champ optionnel le vide.
  ActivityLog copyWith({
    String? id,
    String? childId,
    String? activityTypeId,
    DateTime? timestamp,
    Object? note = kUndefined,
    List<String>? photoPaths,
    Object? evaluationStatusId = kUndefined,
    Map<String, String>? photoCaptions,
    Object? audioPath = kUndefined,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      timestamp: timestamp ?? this.timestamp,
      note: note == kUndefined ? this.note : note as String?,
      photoPaths: photoPaths ?? this.photoPaths,
      evaluationStatusId: evaluationStatusId == kUndefined
          ? this.evaluationStatusId
          : evaluationStatusId as String?,
      legacyStatusLabel: legacyStatusLabel,
      photoCaptions: photoCaptions ?? this.photoCaptions,
      audioPath: audioPath == kUndefined ? this.audioPath : audioPath as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'activityTypeId': activityTypeId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'photoPaths': photoPaths,
      'evaluationStatusId': evaluationStatusId,
      // Conserve tant qu'il existe : permet de revenir a une version
      // anterieure sans perdre l'evaluation deja saisie.
      if (legacyStatusLabel != null) 'evaluationStatus': legacyStatusLabel,
      'photoCaptions': photoCaptions,
      'audioPath': audioPath,
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
      evaluationStatusId: map['evaluationStatusId'],
      legacyStatusLabel: map['evaluationStatus'],
      photoCaptions: Map<String, String>.from(map['photoCaptions'] ?? {}),
      audioPath: map['audioPath'],
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityLog.fromJson(String source) => ActivityLog.fromMap(json.decode(source));
}
