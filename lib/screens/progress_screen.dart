import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/sons_data.dart';
import '../utils/color_utils.dart';
import '../widgets/radar_chart.dart';

enum _ViewMode { chart, radar, table }

const _acquisColor = Color(0xFF388E3C);
const _enCoursColor = Color(0xFFF9A825);
const _nonAcquisColor = Color(0xFFD32F2F);

/// Un point d'historique generique : un item a change de statut a un instant
/// donne. Constitue a partir de [SonHistoryEntry] ou [ReferentialHistoryEntry]
/// par l'ecran appelant.
class HistoryPoint {
  final String itemId;
  final SonStatut statut;
  final DateTime changedAt;

  const HistoryPoint({required this.itemId, required this.statut, required this.changedAt});
}

class _PeriodSnapshot {
  final String label;
  final int acquis;
  final int enCours;
  final int nonAcquis;

  const _PeriodSnapshot({
    required this.label,
    required this.acquis,
    required this.enCours,
    required this.nonAcquis,
  });
}

/// Évolution dans le temps d'un suivi a 3 etats (sons ou referentiel
/// personnalise) : graphique en barres, radar par groupe, ou tableau.
///
/// Generique : ne connait ni les sons ni les referentiels, seulement des
/// items identifies par une chaine et un historique de statuts. Reconstruit,
/// a partir de cet historique append-only, un instantane du nombre d'items
/// acquis / en cours / non acquis a la fin de chaque periode. Ne remonte que
/// depuis l'activation du suivi concerne : rien n'est reconstitue avant.
class ProgressScreen extends StatefulWidget {
  final String title;
  final int totalItems;
  final Future<List<HistoryPoint>> Function() loadHistory;
  final List<RadarChartAxis> Function() buildRadarAxes;
  final String emptyStateMessage;

  const ProgressScreen({
    super.key,
    required this.title,
    required this.totalItems,
    required this.loadHistory,
    required this.buildRadarAxes,
    required this.emptyStateMessage,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<HistoryPoint>? _history;
  _ViewMode _viewMode = _ViewMode.chart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await widget.loadHistory();
    if (mounted) setState(() => _history = history);
  }

  List<_PeriodSnapshot> _buildSnapshots(List<HistoryPoint> history) {
    if (history.isEmpty) return [];
    final now = DateTime.now();
    final first = history.first.changedAt;
    final spanDays = now.difference(first).inDays;
    // Semaine par semaine sur un historique recent, sinon mois par mois pour
    // ne pas etaler le graphique sur des dizaines de barres.
    final bucketDays = spanDays > 70 ? 28 : 7;
    final fmt = DateFormat(bucketDays > 7 ? 'MMM yy' : 'dd/MM');

    final boundaries = <DateTime>[];
    var b = first.add(Duration(days: bucketDays));
    while (b.isBefore(now)) {
      boundaries.add(b);
      b = b.add(Duration(days: bucketDays));
    }
    boundaries.add(now);

    final current = <String, SonStatut>{};
    var idx = 0;
    return boundaries.map((boundary) {
      while (idx < history.length && !history[idx].changedAt.isAfter(boundary)) {
        current[history[idx].itemId] = history[idx].statut;
        idx++;
      }
      final acquis = current.values.where((s) => s == SonStatut.acquis).length;
      final enCours = current.values.where((s) => s == SonStatut.enCours).length;
      return _PeriodSnapshot(
        label: fmt.format(boundary),
        acquis: acquis,
        enCours: enCours,
        nonAcquis: widget.totalItems - acquis - enCours,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _history == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(_buildSnapshots(_history!)),
    );
  }

  Widget _buildBody(List<_PeriodSnapshot> snapshots) {
    // Le radar est un instantane de l'etat actuel : toujours disponible, meme
    // sans historique. Le graphique et le tableau, eux, dependent de
    // l'historique et restent vides tant qu'aucun pointage n'a ete fait.
    if (snapshots.isEmpty && _viewMode != _ViewMode.radar) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Pas encore d\'historique',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptyStateMessage,
              style: const TextStyle(fontSize: 13, color: kMutedTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _viewMode = _ViewMode.radar),
              icon: const Icon(Icons.radar, size: 18),
              label: const Text('Voir le profil actuel (radar)'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _viewMode == _ViewMode.radar
                    ? const Text(
                        'Répartition actuelle par groupe',
                        style: TextStyle(fontSize: 12, color: kMutedTextColor),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _legendItem(_acquisColor, 'Acquis'),
                          _legendItem(_enCoursColor, 'En cours'),
                          _legendItem(_nonAcquisColor, 'Non acquis'),
                        ],
                      ),
              ),
              SegmentedButton<_ViewMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _ViewMode.chart, icon: Icon(Icons.bar_chart, size: 18)),
                  ButtonSegment(value: _ViewMode.radar, icon: Icon(Icons.radar, size: 18)),
                  ButtonSegment(value: _ViewMode.table, icon: Icon(Icons.table_chart_outlined, size: 18)),
                ],
                selected: {_viewMode},
                onSelectionChanged: (selection) => setState(() => _viewMode = selection.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_viewMode) {
            _ViewMode.chart => _buildChart(snapshots),
            _ViewMode.table => _buildTable(snapshots),
            _ViewMode.radar => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: RadarChart(axes: widget.buildRadarAxes()),
                ),
              ),
          },
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildChart(List<_PeriodSnapshot> snapshots) {
    const barHeight = 160.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: snapshots.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${s.label} : ${s.acquis} acquis, ${s.enCours} en cours, ${s.nonAcquis} non acquis',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              ),
              child: Column(
                children: [
                  Text('${s.acquis}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _acquisColor)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: barHeight,
                    width: 30,
                    child: Column(
                      children: [
                        if (s.nonAcquis > 0)
                          Expanded(
                            flex: s.nonAcquis,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: _nonAcquisColor,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        if (s.nonAcquis > 0 && (s.enCours > 0 || s.acquis > 0)) const SizedBox(height: 2),
                        if (s.enCours > 0)
                          Expanded(
                            flex: s.enCours,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _enCoursColor,
                                borderRadius: s.nonAcquis == 0
                                    ? const BorderRadius.vertical(top: Radius.circular(4))
                                    : null,
                              ),
                            ),
                          ),
                        if (s.enCours > 0 && s.acquis > 0) const SizedBox(height: 2),
                        if (s.acquis > 0)
                          Expanded(
                            flex: s.acquis,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _acquisColor,
                                borderRadius: BorderRadius.vertical(
                                  top: (s.nonAcquis == 0 && s.enCours == 0) ? const Radius.circular(4) : Radius.zero,
                                  bottom: const Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(s.label, style: const TextStyle(fontSize: 11, color: kMutedTextColor)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(List<_PeriodSnapshot> snapshots) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Période')),
          DataColumn(label: Text('Acquis'), numeric: true),
          DataColumn(label: Text('En cours'), numeric: true),
          DataColumn(label: Text('Non acquis'), numeric: true),
        ],
        rows: snapshots
            .map((s) => DataRow(cells: [
                  DataCell(Text(s.label)),
                  DataCell(Text('${s.acquis}')),
                  DataCell(Text('${s.enCours}')),
                  DataCell(Text('${s.nonAcquis}')),
                ]))
            .toList(),
      ),
    );
  }
}
