import 'dart:convert';

class ActivityLog {
  final String id;
  final String childId;
  final String activityTypeId;
  final DateTime timestamp;
  final String? note;
  final List<String> photoPaths;
  final String? evaluationStatus;

  ActivityLog({
    required this.id,
    required this.childId,
    required this.activityTypeId,
    required this.timestamp,
    this.note,
    this.photoPaths = const [],
    this.evaluationStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'activityTypeId': activityTypeId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'photoPaths': photoPaths,
      'evaluationStatus': evaluationStatus,
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
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityLog.fromJson(String source) => ActivityLog.fromMap(json.decode(source));
}
