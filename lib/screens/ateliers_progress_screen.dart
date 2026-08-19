import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/atelier_status_resolver.dart';
import '../services/child_ateliers_breakdown.dart';
import '../utils/app_icons.dart';
import 'atelier_history_screen.dart';
import 'ateliers_class_progress_screen.dart';

enum _QuickPeriod { toutes, semaine, mois, personnalise }

/// Suivi par atelier d'un eleve : seuls les ateliers pertinents pour sa
/// section sont montres (meme regle que le scan/la saisie manuelle), avec
/// leur statut le plus recent sur la periode choisie.
class AteliersProgressScreen extends StatefulWidget {
  final Child child;

  const AteliersProgressScreen({super.key, required this.child});

  @override
  State<AteliersProgressScreen> createState() => _AteliersProgressScreenState();
}

class _AteliersProgressScreenState extends State<AteliersProgressScreen> {
  DateTimeRange? _period;
  _QuickPeriod _quick = _QuickPeriod.toutes;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  void _setQuick(_QuickPeriod period) {
    final now = DateTime.now();
    setState(() {
      _quick = period;
      switch (period) {
        case _QuickPeriod.toutes:
          _period = null;
          break;
        case _QuickPeriod.semaine:
          _period = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
          break;
        case _QuickPeriod.mois:
          _period = DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now);
          break;
        case _QuickPeriod.personnalise:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _period,
    );
    if (picked == null) return;
    setState(() {
      _quick = _QuickPeriod.personnalise;
      _period = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final breakdown = ChildAteliersBreakdown.compute(provider: provider, child: widget.child, period: _period);
    final aFaire = breakdown.aFaire;
    final realise = breakdown.realise;
    final snapshots = breakdown.snapshots;
    final statusCounts = breakdown.statusCounts;
    final aFaireCount = aFaire.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ateliers · ${widget.child.firstname}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Voir toute la classe',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AteliersClassProgressScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tete fixe : reste visible meme quand la liste en dessous defile.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Toutes dates'),
                  selected: _quick == _QuickPeriod.toutes,
                  onSelected: (_) => _setQuick(_QuickPeriod.toutes),
                ),
                ChoiceChip(
                  label: const Text('Cette semaine'),
                  selected: _quick == _QuickPeriod.semaine,
                  onSelected: (_) => _setQuick(_QuickPeriod.semaine),
                ),
                ChoiceChip(
                  label: const Text('Ce mois-ci'),
                  selected: _quick == _QuickPeriod.mois,
                  onSelected: (_) => _setQuick(_QuickPeriod.mois),
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _quick == _QuickPeriod.personnalise && _period != null
                        ? '${_dateFormat.format(_period!.start)} → ${_dateFormat.format(_period!.end)}'
                        : 'Personnalisé…',
                  ),
                  onPressed: _pickCustomRange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _summaryChip('À faire', aFaireCount, Colors.grey),
                for (final status in provider.evaluationStatuses)
                  if ((statusCounts[status.id] ?? 0) > 0)
                    _summaryChip(
                      status.label,
                      statusCounts[status.id]!,
                      Color(int.parse(status.colorHex.replaceFirst('#', '0xff'))),
                    ),
                // Observation enregistree sans niveau d'evaluation choisi :
                // rare, mais sinon son compte disparaissait du resume.
                if ((statusCounts['sans_statut'] ?? 0) > 0)
                  _summaryChip('Sans statut', statusCounts['sans_statut']!, Colors.blueGrey),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: breakdown.totalCount == 0
                ? const Center(child: Text('Aucun atelier configuré pour la section de cet élève.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (aFaire.isNotEmpty) ...[
                        _buildSectionHeader('⏳ À faire', aFaire.length, Colors.orange),
                        ..._buildGroupedBySpace(provider, aFaire, snapshots),
                        const SizedBox(height: 16),
                      ],
                      if (realise.isNotEmpty) ...[
                        _buildSectionHeader('✅ Réalisé', realise.length, const Color(0xFF4E9F3D)),
                        ..._buildGroupedBySpace(provider, realise, snapshots),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$count $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$title ($count)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
    );
  }

  List<Widget> _buildGroupedBySpace(
    AppStateProvider provider,
    List<MapEntry<ActivityType, AtelierEligibilityResult>> entries,
    Map<String, AtelierStatusSnapshot> snapshots,
  ) {
    final bySpace = <String, List<MapEntry<ActivityType, AtelierEligibilityResult>>>{};
    for (final entry in entries) {
      (bySpace[entry.key.spaceId] ??= []).add(entry);
    }
    final spaceIds = bySpace.keys.toList()
      ..sort((a, b) => (provider.spaceById(a)?.name ?? '').compareTo(provider.spaceById(b)?.name ?? ''));

    return [
      for (final spaceId in spaceIds) ...[
        _buildSpaceHeader(provider.spaceById(spaceId)),
        ...bySpace[spaceId]!.map((e) => _buildAtelierRow(provider, e.key, e.value, snapshots[e.key.id])),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _buildSpaceHeader(Space? space) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        space?.name ?? 'Sans espace',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF4E9F3D)),
      ),
    );
  }

  Widget _buildAtelierRow(
    AppStateProvider provider,
    ActivityType atelier,
    AtelierEligibilityResult eligibility,
    AtelierStatusSnapshot? snapshot,
  ) {
    if (eligibility.status == AtelierEligibility.blockedProgression) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline, color: Colors.grey),
          title: Text(atelier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(eligibility.message, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }

    final label = snapshot?.label ?? '';
    final color = snapshot != null ? Color(int.parse(snapshot.colorHex.replaceFirst('#', '0xff'))) : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Color(int.parse(atelier.colorHex.replaceFirst('#', '0xff'))),
          child: Icon(iconForName(atelier.iconName, fallback: Icons.palette), size: 14, color: Colors.white),
        ),
        title: Text(atelier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: eligibility.status == AtelierEligibility.allowedWithWarning
            ? Text(eligibility.message, style: const TextStyle(fontSize: 11, color: Colors.orange))
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AtelierHistoryScreen(child: widget.child, atelier: atelier)),
        ),
      ),
    );
  }
}
