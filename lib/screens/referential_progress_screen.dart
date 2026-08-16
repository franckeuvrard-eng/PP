import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sons_data.dart';
import '../models/child.dart';
import '../models/referential.dart';
import '../providers/app_provider.dart';
import '../widgets/radar_chart.dart';
import 'progress_screen.dart';

/// Évolution dans le temps d'un référentiel personnalisé pour un élève :
/// habille [ProgressScreen] (générique, partagé avec les sons) avec les
/// données propres au référentiel choisi.
class ReferentialProgressScreen extends StatelessWidget {
  final Child child;
  final Referential referential;

  const ReferentialProgressScreen({super.key, required this.child, required this.referential});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final allItems = referential.allItems;
    return ProgressScreen(
      title: '${referential.name} — ${child.firstname}',
      totalItems: allItems.length,
      emptyStateMessage: 'Le graphique se construit au fil des prochains pointages : '
          'il ne peut pas reconstituer ce qui précède l\'activation de ce suivi.',
      loadHistory: () async {
        final history = await provider.referentialHistory(referential.id, child.id);
        return history
            .map((e) => HistoryPoint(itemId: e.itemId, statut: e.statut, changedAt: e.changedAt))
            .toList();
      },
      buildRadarAxes: () => referential.groups.map((group) {
        var score = 0.0;
        for (final item in group.items) {
          score += switch (provider.referentialItemStatut(referential.id, child.id, item.id)) {
            SonStatut.acquis => 1.0,
            SonStatut.enCours => 0.5,
            SonStatut.nonAcquis => 0.0,
          };
        }
        return RadarChartAxis(
          label: group.title,
          value: group.items.isEmpty ? 0 : score / group.items.length,
        );
      }).toList(),
    );
  }
}
