import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../services/excel_export_service.dart';
import '../utils/app_icons.dart';

enum StatsPeriod { all, today, week, month }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.all;

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
    final Map<String, Map<String, int>> childStatusCounts = {
      for (var c in children) c.id: {for (var s in statuses) s: 0}
    };

    final Map<String, int> typeActivityCounts = {for (var t in types) t.id: 0};
    final Map<String, int> domainCounts = {};
    final Map<String, int> evaluationCounts = {for (var s in statuses) s: 0};
    int unratedCount = 0;

    for (var act in filteredActivities) {
      // Child stats
      if (childActivityCounts.containsKey(act.childId)) {
        childActivityCounts[act.childId] = childActivityCounts[act.childId]! + 1;
      }
      if (act.evaluationStatus != null && childStatusCounts.containsKey(act.childId)) {
        final cMap = childStatusCounts[act.childId]!;
        cMap[act.evaluationStatus!] = (cMap[act.evaluationStatus!] ?? 0) + 1;
      }

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
      if (act.evaluationStatus != null && evaluationCounts.containsKey(act.evaluationStatus!)) {
        evaluationCounts[act.evaluationStatus!] = evaluationCounts[act.evaluationStatus!]! + 1;
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
                    final count = evaluationCounts[status] ?? 0;
                    final total = filteredActivities.isEmpty ? 1 : filteredActivities.length;
                    final ratio = count / total;
                    final color = _getStatusColor(status);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
            const Text('Progression Détaillée par Élève', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  final totalCount = childActivityCounts[child.id] ?? 0;
                  final sMap = childStatusCounts[child.id] ?? {};
                  // Les libelles de statut sont parametrables et contiennent des
                  // emojis, donc on compare sur le libelle normalise.
                  final acquisCount = sMap.entries
                      .where((e) => _normalizeStatus(e.key).startsWith('acquis'))
                      .fold<int>(0, (sum, e) => sum + e.value);

                  return ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
                      child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$totalCount activité(s) enregistrée(s)', style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E9F3D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$acquisCount Acquis', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D), fontSize: 12)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Détail des évaluations :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: statuses.map((st) {
                                final cnt = sMap[st] ?? 0;
                                final col = _getStatusColor(st);
                                return Chip(
                                  backgroundColor: col.withOpacity(0.1),
                                  side: BorderSide(color: col.withOpacity(0.3)),
                                  label: Text('$st : $cnt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
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
                      child: const Icon(Icons.palette, color: Colors.white, size: 18),
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

  /// Retire les emojis et la ponctuation d'un libelle de statut pour permettre
  /// une comparaison stable, quels que soient les statuts saisis dans les
  /// parametres (ex. 'Acquis 🟢' -> 'acquis').
  String _normalizeStatus(String status) {
    return status
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-zà-ÿ' ]"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Color _getStatusColor(String status) {
    final s = _normalizeStatus(status);
    if (s.startsWith('non acquis')) return const Color(0xFFD32F2F);
    if (s.startsWith('acquis')) return const Color(0xFF388E3C);
    if (s.startsWith('en cours')) return const Color(0xFFF57C00);
    if (s.startsWith('à revoir') || s.startsWith('a revoir')) {
      return const Color(0xFF7B1FA2);
    }
    return const Color(0xFF1976D2);
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
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
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
                                    child: Text(c.avatarText, style: const TextStyle(fontSize: 10, color: Colors.white)),
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
                                    child: Text(c.avatarText, style: const TextStyle(fontSize: 10, color: Colors.white)),
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
