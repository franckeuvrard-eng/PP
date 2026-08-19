import 'package:flutter/material.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import 'atelier_eligibility_service.dart';
import 'atelier_status_resolver.dart';

/// Repartition des ateliers d'un eleve (limites a sa section) entre ceux
/// restant a faire et ceux deja realises sur une periode donnee, avec le
/// compte par statut. Partage entre le suivi individuel par atelier et la
/// "Progression Detaillee par Eleve" des Statistiques, pour que les deux
/// vues comptent exactement la meme chose.
class ChildAteliersBreakdown {
  final List<MapEntry<ActivityType, AtelierEligibilityResult>> aFaire;
  final List<MapEntry<ActivityType, AtelierEligibilityResult>> realise;
  final Map<String, AtelierStatusSnapshot> snapshots;
  final Map<String, int> statusCounts;

  const ChildAteliersBreakdown({
    required this.aFaire,
    required this.realise,
    required this.snapshots,
    required this.statusCounts,
  });

  int get totalCount => aFaire.length + realise.length;

  static ChildAteliersBreakdown compute({
    required AppStateProvider provider,
    required Child child,
    DateTimeRange? period,
  }) {
    final annotated = AtelierEligibilityService.annotate(provider: provider, child: child)
        .where((e) => e.value.status != AtelierEligibility.blockedSection)
        .toList();

    final aFaire = <MapEntry<ActivityType, AtelierEligibilityResult>>[];
    final realise = <MapEntry<ActivityType, AtelierEligibilityResult>>[];
    final snapshots = <String, AtelierStatusSnapshot>{};
    final statusCounts = <String, int>{};

    for (final entry in annotated) {
      if (entry.value.status == AtelierEligibility.blockedProgression) {
        aFaire.add(entry);
        continue;
      }
      final snapshot = AtelierStatusResolver.resolve(
        provider: provider,
        childId: child.id,
        activityTypeId: entry.key.id,
        period: period,
      );
      snapshots[entry.key.id] = snapshot;
      if (!snapshot.hasLogInPeriod) {
        aFaire.add(entry);
      } else {
        realise.add(entry);
        statusCounts[snapshot.statusId!] = (statusCounts[snapshot.statusId!] ?? 0) + 1;
      }
    }

    return ChildAteliersBreakdown(aFaire: aFaire, realise: realise, snapshots: snapshots, statusCounts: statusCounts);
  }
}
