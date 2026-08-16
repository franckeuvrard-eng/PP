import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sons_data.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../widgets/radar_chart.dart';
import 'progress_screen.dart';

/// Évolution dans le temps de l'analyse des sons d'un élève : habille
/// [ProgressScreen] (générique) avec les données propres aux sons.
class SonsProgressScreen extends StatelessWidget {
  final Child child;

  const SonsProgressScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    return ProgressScreen(
      title: 'Progression — ${child.firstname}',
      totalItems: SonsData.tous.length,
      emptyStateMessage: 'Le graphique se construit au fil des prochains pointages de sons : '
          'il ne peut pas reconstituer ce qui précède l\'activation de ce suivi.',
      loadHistory: () async {
        final history = await provider.sonHistory(child.id);
        return history
            .map((e) => HistoryPoint(itemId: e.son, statut: e.statut, changedAt: e.changedAt))
            .toList();
      },
      buildRadarAxes: () => SonsData.groupes.map((groupe) {
        var score = 0.0;
        for (final son in groupe.sons) {
          score += switch (provider.sonStatut(child.id, son)) {
            SonStatut.acquis => 1.0,
            SonStatut.enCours => 0.5,
            SonStatut.nonAcquis => 0.0,
          };
        }
        return RadarChartAxis(
          label: groupe.titre,
          value: groupe.sons.isEmpty ? 0 : score / groupe.sons.length,
        );
      }).toList(),
    );
  }
}
