import 'dart:convert';

class ActivityLog {
  final String id;
  final String childId;
  final String activityTypeId;
  final DateTime timestamp;
  final String emotion;
  final String? note;
  final String? photoPath;

  ActivityLog({
    required this.id,
    required this.childId,
    required this.activityTypeId,
    required this.timestamp,
    required this.emotion,
    this.note,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'activityTypeId': activityTypeId,
      'timestamp': timestamp.toIso8601String(),
      'emotion': emotion,
      'note': note,
      'photoPath': photoPath,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      childId: map['childId'] ?? '',
      activityTypeId: map['activityTypeId'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      emotion: map['emotion'] ?? '😊 Joyeux',
      note: map['note'],
      photoPath: map['photoPath'],
    );
  }

  String toJson() => json.encode(toMap());
  factory ActivityLog.fromJson(String source) => ActivityLog.fromMap(json.decode(source));
}
