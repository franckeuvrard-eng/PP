import 'package:intl/intl.dart';

/// Un creneau du planning : un jour de la semaine, un groupe d'eleves, les
/// ateliers (ou etapes) qu'il fait ce jour-la.
class PlanningSlot {
  final String id;

  /// Lundi de la semaine (`yyyy-MM-dd`).
  final String week;

  /// Jour : 1 (lundi) a 5 (vendredi).
  final int day;

  /// Qui : [allClass], `section:<nom>` ou `group:<id de NeedGroup>`.
  final String target;
  final List<String> atelierIds;

  static const allClass = 'all';

  PlanningSlot({
    required this.id,
    required this.week,
    required this.day,
    required this.target,
    this.atelierIds = const [],
  });

  /// Lundi de la semaine qui contient [d], au format de [week].
  static String weekOf(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  DateTime get date => DateTime.parse(week).add(Duration(days: day - 1));

  PlanningSlot copyWith({String? target, List<String>? atelierIds, int? day}) => PlanningSlot(
        id: id,
        week: week,
        day: day ?? this.day,
        target: target ?? this.target,
        atelierIds: atelierIds ?? this.atelierIds,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'week': week,
        'day': day,
        'target': target,
        'atelierIds': atelierIds,
      };

  factory PlanningSlot.fromMap(Map<String, dynamic> map) => PlanningSlot(
        id: map['id'] ?? '',
        week: map['week'] ?? '',
        day: (map['day'] as num?)?.toInt() ?? 1,
        target: map['target'] ?? allClass,
        atelierIds: List<String>.from(map['atelierIds'] ?? const []),
      );
}
