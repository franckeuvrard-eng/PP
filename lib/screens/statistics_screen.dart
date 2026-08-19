import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../data/eduscol_data.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/atelier_status_resolver.dart';
import '../services/child_ateliers_breakdown.dart';
import '../services/excel_export_service.dart';
import '../utils/app_icons.dart';
import 'atelier_history_screen.dart';
import 'ateliers_class_progress_screen.dart';

enum StatsPeriod { all, today, week, month }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.all;

  /// Traduit le filtre de periode de cet ecran en plage de dates, pour que
  /// le detail par atelier compte sur la meme periode que le reste de la
  /// page plutot que de redefinir son propre selecteur.
  DateTimeRange? _periodAsRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case StatsPeriod.today:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case StatsPeriod.week:
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case StatsPeriod.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case StatsPeriod.all:
      default:
        return null;
    }
  }

  List<ActivityLog> _filterLogs(List<ActivityLog> logs) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case StatsPeriod.today:
        return logs.where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day).toList();
      case StatsPeriod.week:
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        return logs.where((l) => l.timestamp.isAfter(sevenDaysAgo)).toList();
      case StatsPeriod.month:
        return logs.where((l) =>
            l.timestamp.year == now.year && l.timestamp.month == now.month).toList();
      case StatsPeriod.all:
      default:
        return logs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppStateProvider>(context);
    final allActivities = provider.activities;
    final filteredActivities = _filterLogs(allActivities);
    final children = provider.children;
    final types = provider.activityTypes;
    final statuses = provider.evaluationStatuses;

    // Stats calculations
    final Map<String, int> childActivityCounts = {for (var c in children) c.id: 0};

    final Map<String, int> typeActivityCounts = {for (var t in types) t.id: 0};
    final Map<String, int> domainCounts = {};
    final Map<String, int> evaluationCounts = {for (var s in statuses) s.id: 0};
    int unratedCount = 0;

    for (var act in filteredActivities) {
      // Child stats
      if (childActivityCounts.containsKey(act.childId)) {
        childActivityCounts[act.childId] = childActivityCounts[act.childId]! + 1;
      }
      final statusId = act.evaluationStatusId;

      // Type & Domain stats
      if (typeActivityCounts.containsKey(act.activityTypeId)) {
        typeActivityCounts[act.activityTypeId] = typeActivityCounts[act.activityTypeId]! + 1;
      }
      final actType = types.firstWhere(
        (t) => t.id == act.activityTypeId,
        orElse: () => ActivityType(id: '', name: '', spaceId: '', colorHex: '#718096'),
      );
      final space = provider.spaces.firstWhere(
        (s) => s.id == actType.spaceId,
        orElse: () => Space(id: '', name: 'Autre', colorHex: '#718096'),
      );
      final cat = space.name.isNotEmpty ? space.name : 'Autre';
      domainCounts[cat] = (domainCounts[cat] ?? 0) + 1;

      // Evaluation stats
      if (statusId != null && evaluationCounts.containsKey(statusId)) {
        evaluationCounts[statusId] = evaluationCounts[statusId]! + 1;
      } else {
        unratedCount++;
      }
    }

    final sortedChildren = children.toList()
      ..sort((a, b) => (childActivityCounts[b.id] ?? 0).compareTo(childActivityCounts[a.id] ?? 0));

    final sortedTypes = types.toList()
      ..sort((a, b) => (typeActivityCounts[b.id] ?? 0).compareTo(typeActivityCounts[a.id] ?? 0));

    final sortedDomains = domainCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord & Statistiques'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
        actions: [
          Builder(
            builder: (btnContext) {
              return IconButton(
                icon: const Icon(Icons.table_chart, color: Colors.white),
                tooltip: 'Exporter la classe (Excel)',
                onPressed: () {
                  final box = btnContext.findRenderObject() as RenderBox?;
                  final Rect? sharePositionOrigin = box != null && box.hasSize
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  ExcelExportService.exportFullClass(
                    context: context,
                    provider: provider,
                    children: children,
                    logs: filteredActivities,
                    sharePositionOrigin: sharePositionOrigin,
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Period Filter Chips ───
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip(StatsPeriod.all, 'Tout l\'historique'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(StatsPeriod.today, 'Aujourd\'hui'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(StatsPeriod.week, '7 derniers jours'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(StatsPeriod.month, 'Ce mois-ci'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── KPI Overview Cards ───
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Activités',
                    value: '${filteredActivities.length}',
                    icon: Icons.auto_graph,
                    color: isDark ? const Color(0xFF1A2744) : const Color(0xFFE3F2FD),
                    textColor: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Élèves Actifs',
                    value: '${sortedChildren.where((c) => (childActivityCounts[c.id] ?? 0) > 0).length} / ${children.length}',
                    icon: Icons.people,
                    color: isDark ? const Color(0xFF3B2E15) : const Color(0xFFFFF3E0),
                    textColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Répartition par domaine Éduscol ───
            _buildDomainSection(context, filteredActivities, types, isDark),
            const SizedBox(height: 24),

            // ─── Mandatory Workshops Tracking ───
            _buildMandatoryWorkshopsSection(context, provider, filteredActivities, children, types),
            const SizedBox(height: 24),

            // ─── Evaluation Status Breakdown ───
            const Text('Répartition des Évaluations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  ...statuses.map((status) {
                    final count = evaluationCounts[status.id] ?? 0;
                    final total = filteredActivities.isEmpty ? 1 : filteredActivities.length;
                    final ratio = count / total;
                    final color = Color(int.parse(status.colorHex.replaceFirst('#', '0xff')));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(status.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('$count (${(ratio * 100).toStringAsFixed(1)}%)', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: color.withOpacity(0.15),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (unratedCount > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Non évalué / Note libre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('$unratedCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Domain / Category Breakdown ───
            if (sortedDomains.isNotEmpty) ...[
              const Text('Activités par Domaine d\'Apprentissage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: sortedDomains.map((entry) {
                    final total = filteredActivities.isEmpty ? 1 : filteredActivities.length;
                    final ratio = entry.value / total;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${entry.value} (${(ratio * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: const Color(0xFF4E9F3D).withOpacity(0.15),
                              color: const Color(0xFF4E9F3D),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Child Detailed Progress ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progression Détaillée par Élève', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AteliersClassProgressScreen()),
                  ),
                  icon: const Icon(Icons.grid_on, size: 16),
                  label: const Text('Détail par atelier'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedChildren.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final child = sortedChildren[index];
                  // Repartition par atelier de la section de l'eleve, sur la
                  // meme periode que le reste de cet ecran : c'est elle qui
                  // pilote le compteur et la liste depliee, pas seulement le
                  // compte brut d'observations toutes ateliers confondues.
                  final breakdown = ChildAteliersBreakdown.compute(
                    provider: provider,
                    child: child,
                    period: _periodAsRange(),
                  );

                  return ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
                      child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (breakdown.aFaire.isNotEmpty) _miniCounter('${breakdown.aFaire.length} à faire', Colors.grey),
                          for (final st in statuses)
                            if ((breakdown.statusCounts[st.id] ?? 0) > 0)
                              _miniCounter(
                                '${breakdown.statusCounts[st.id]} ${st.label}',
                                Color(int.parse(st.colorHex.replaceFirst('#', '0xff'))),
                              ),
                          // Observation enregistree sans niveau d'evaluation choisi :
                          // rare, mais sinon son compte disparaissait du resume.
                          if ((breakdown.statusCounts['sans_statut'] ?? 0) > 0)
                            _miniCounter('${breakdown.statusCounts['sans_statut']} sans statut', Colors.blueGrey),
                          if (breakdown.totalCount == 0)
                            const Text('Aucun atelier configuré pour sa section', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (breakdown.aFaire.isEmpty ? const Color(0xFF4E9F3D) : Colors.orange).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        breakdown.aFaire.isEmpty ? 'Tout fait' : '${breakdown.aFaire.length} à faire',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: breakdown.aFaire.isEmpty ? const Color(0xFF4E9F3D) : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    children: [
                      if (breakdown.totalCount == 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Aucun atelier ne cible la section de cet élève pour le moment.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (breakdown.aFaire.isNotEmpty) ...[
                                const Text('⏳ À faire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                                ...breakdown.aFaire.map((e) => _childAtelierTile(context, child, e.key, e.value, null)),
                                const SizedBox(height: 8),
                              ],
                              if (breakdown.realise.isNotEmpty) ...[
                                const Text('✅ Réalisé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4E9F3D))),
                                ...breakdown.realise.map(
                                  (e) => _childAtelierTile(context, child, e.key, e.value, breakdown.snapshots[e.key.id]),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // ─── Popular Activities ───
            const Text('Ateliers les plus sollicités', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedTypes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final actType = sortedTypes[index];
                  final count = typeActivityCounts[actType.id] ?? 0;
                  if (count == 0 && filteredActivities.isNotEmpty) return const SizedBox.shrink();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                      child: Icon(iconForName(actType.iconName, fallback: Icons.palette),
                          color: Colors.white, size: 18),
                    ),
                    title: Text(actType.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      provider.spaces.firstWhere((s) => s.id == actType.spaceId, orElse: () => Space(id: '', name: '', colorHex: '')).name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text('$count fois', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Repartition des observations par domaine Eduscol.
  ///
  /// Les domaines officiels sont toujours listes, meme a zero : l'interet est
  /// justement de reperer celui qu'on delaisse.
  Widget _buildDomainSection(
    BuildContext context,
    List<ActivityLog> logs,
    List<ActivityType> types,
    bool isDark,
  ) {
    final typeById = {for (final t in types) t.id: t};
    final counts = <String, int>{
      for (final d in EduscolData.domains) d.title: 0,
    };
    var sansDomaine = 0;

    for (final log in logs) {
      final type = typeById[log.activityTypeId];
      // Le rattachement se fait par identifiant quand l'atelier en porte un ;
      // le libelle ne sert que pour les domaines personnalises.
      final domain = type?.domaineId == null
          ? null
          : EduscolData.domains.where((d) => d.id == type!.domaineId).firstOrNull;
      final key = domain?.title ?? type?.domaine ?? '';
      if (key.isEmpty) {
        sansDomaine++;
      } else {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b) + sansDomaine;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Répartition par domaine Éduscol',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          total == 0
              ? 'Aucune observation sur la période.'
              : 'Les domaines à zéro signalent un apprentissage à programmer.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ...entries.map((entry) {
                final ratio = total == 0 ? 0.0 : entry.value / total;
                final domain = EduscolData.domains.firstWhere(
                  (d) => d.title == entry.key,
                  orElse: () => EduscolData.domains.first,
                );
                final couleur = Color(int.parse(domain.colorHex.replaceFirst('#', '0xff')));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(entry.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: entry.value == 0 ? FontWeight.normal : FontWeight.w600,
                                  color: entry.value == 0 ? Colors.grey : null,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text('${entry.value}',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: couleur)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(couleur),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (sansDomaine > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Ateliers sans domaine renseigné',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),
                      Text('$sansDomaine',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniCounter(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// Ligne d'un atelier dans le detail deplie d'un eleve. [snapshot] est
  /// null pour un atelier verrouille par la progression (aucun statut a
  /// afficher dans ce cas).
  Widget _childAtelierTile(
    BuildContext context,
    Child child,
    ActivityType atelier,
    AtelierEligibilityResult eligibility,
    AtelierStatusSnapshot? snapshot,
  ) {
    if (eligibility.status == AtelierEligibility.blockedProgression) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
        title: Text(atelier.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(eligibility.message, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    final label = snapshot?.label ?? '';
    final color = snapshot != null ? Color(int.parse(snapshot.colorHex.replaceFirst('#', '0xff'))) : Colors.grey;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: Color(int.parse(atelier.colorHex.replaceFirst('#', '0xff'))),
        child: Icon(iconForName(atelier.iconName, fallback: Icons.palette), size: 12, color: Colors.white),
      ),
      title: Text(atelier.name, style: const TextStyle(fontSize: 13)),
      subtitle: eligibility.status == AtelierEligibility.allowedWithWarning
          ? Text(eligibility.message, style: const TextStyle(fontSize: 11, color: Colors.orange))
          : null,
      trailing: label.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AtelierHistoryScreen(child: child, atelier: atelier)),
      ),
    );
  }

  Widget _buildPeriodChip(StatsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF4E9F3D),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = period;
          });
        }
      },
    );
  }


  Widget _buildMandatoryWorkshopsSection(
    BuildContext context,
    AppStateProvider provider,
    List<ActivityLog> logs,
    List<Child> children,
    List<ActivityType> types,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mandatoryTypes = types.where((t) => t.isObligatory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.stars, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Ateliers Obligatoires & Suivi des Retards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (mandatoryTypes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B2E15) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF6B5220) : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: isDark ? const Color(0xFFFFB74D) : Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aucun atelier n\'est configuré comme obligatoire.\nPour rendre un atelier obligatoire, allez dans Paramètres > Espaces & Ateliers et cochez "Atelier Obligatoire".',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFE2E8F0) : Colors.black87),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mandatoryTypes.length,
            itemBuilder: (context, index) {
              final actType = mandatoryTypes[index];
              final space = provider.spaces.firstWhere(
                (s) => s.id == actType.spaceId,
                orElse: () => Space(id: '', name: 'Non défini', colorHex: ''),
              );

              final completedChildIds = logs
                  .where((l) => l.activityTypeId == actType.id)
                  .map((l) => l.childId)
                  .toSet();

              // Un atelier peut n'etre obligatoire que pour certaines sections :
              // le suivi ne porte que sur les eleves reellement concernes.
              final concernedChildren =
                  children.where((c) => actType.isObligatoryForGroup(c.group)).toList();
              final completedChildren = concernedChildren.where((c) => completedChildIds.contains(c.id)).toList();
              final missingChildren = concernedChildren.where((c) => !completedChildIds.contains(c.id)).toList();
              // Sans eleve concerne il n'y a rien a realiser : on evite
              // d'afficher une barre rouge trompeuse.
              final ratio = concernedChildren.isEmpty
                  ? 1.0
                  : completedChildren.length / concernedChildren.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                    child: Icon(iconForName(actType.iconName, fallback: Icons.stars), color: Colors.white, size: 20),
                  ),
                  title: Text(actType.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📍 Espace : ${space.name}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        actType.obligatoryGroups.isEmpty
                            ? '👥 Toute la classe'
                            : '👥 ${actType.obligatoryGroups.join(', ')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (concernedChildren.isEmpty)
                        const Text('Aucun élève dans les sections ciblées.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: Colors.red.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ratio == 1.0 ? const Color(0xFF4E9F3D) : Colors.orange,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${completedChildren.length} / ${concernedChildren.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Élèves n\'ayant pas réalisé cet atelier (${missingChildren.length}) :',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (missingChildren.isEmpty)
                            const Text('🎉 Bravo ! Tous les élèves ont réalisé cet atelier obligatoire.', style: TextStyle(fontSize: 12, color: Color(0xFF4E9F3D), fontWeight: FontWeight.bold))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: missingChildren.map((c) {
                                return Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(int.parse(c.colorHex.replaceFirst('#', '0xff'))),
                                    child: Text(c.avatarText, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                                  label: Text('${c.firstname} ${c.lastname ?? ""}', style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.red.shade50,
                                  side: BorderSide(color: Colors.red.shade200),
                                );
                              }).toList(),
                            ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF4E9F3D), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Élèves ayant validé (${completedChildren.length}) :',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4E9F3D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (completedChildren.isEmpty)
                            const Text('Aucun élève n\'a encore réalisé cet atelier.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: completedChildren.map((c) {
                                return Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(int.parse(c.colorHex.replaceFirst('#', '0xff'))),
                                    child: Text(c.avatarText, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                                  label: Text('${c.firstname} ${c.lastname ?? ""}', style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.green.shade50,
                                  side: BorderSide(color: Colors.green.shade200),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            // Un cercle blanc franc sur une carte sombre etait trop dur :
            // en mode sombre on utilise une pastille teintee.
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? textColor.withOpacity(0.18)
                : Colors.white,
            foregroundColor: textColor,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
