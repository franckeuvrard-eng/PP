import 'package:flutter/material.dart';
import '../providers/app_provider.dart';

/// Statut le plus recent d'un atelier pour un eleve, sur une periode donnee.
class AtelierStatusSnapshot {
  final String label;
  final String colorHex;
  final bool hasAnyLog;

  /// Identifiant du niveau d'evaluation le plus recent **dans la periode**,
  /// ou null si aucune observation n'y figure (qu'il y en ait eu avant ou
  /// jamais). Sert a regrouper « a faire » sans dependre du libelle, qui est
  /// personnalisable.
  final String? statusId;

  bool get hasLogInPeriod => statusId != null;

  const AtelierStatusSnapshot({
    required this.label,
    required this.colorHex,
    required this.hasAnyLog,
    this.statusId,
  });
}

/// Resout le statut affichable d'un atelier pour un eleve : dernier
/// [ActivityLog] dans la periode donnee, ou message adapte si aucune
/// observation ne s'y trouve. Partage entre le suivi par atelier (analyse
/// par eleve) et le rapport PDF des ateliers obligatoires, pour ne pas
/// redefinir deux fois la meme regle.
class AtelierStatusResolver {
  static AtelierStatusSnapshot resolve({
    required AppStateProvider provider,
    required String childId,
    required String activityTypeId,
    DateTimeRange? period,
  }) {
    final allLogs = provider.activitiesForChild(childId).where((l) => l.activityTypeId == activityTypeId).toList();
    final periodLogs = period == null
        ? allLogs
        : allLogs
            .where((l) => !l.timestamp.isBefore(period.start) && !l.timestamp.isAfter(period.end.add(const Duration(days: 1))))
            .toList();

    if (periodLogs.isEmpty) {
      return AtelierStatusSnapshot(
        label: allLogs.isEmpty ? 'Jamais fait' : 'Non fait sur la période',
        colorHex: '#9E9E9E',
        hasAnyLog: allLogs.isNotEmpty,
      );
    }

    periodLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latest = periodLogs.first;
    final status = provider.statusById(latest.evaluationStatusId);
    return AtelierStatusSnapshot(
      label: provider.statusLabel(latest) ?? 'Sans statut',
      colorHex: status?.colorHex ?? '#9E9E9E',
      hasAnyLog: true,
      statusId: latest.evaluationStatusId ?? 'sans_statut',
    );
  }
}
