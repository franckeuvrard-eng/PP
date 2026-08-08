import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/child.dart';
import '../models/activity_type.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final activities = provider.activities;
    final children = provider.children;
    final types = provider.activityTypes;

    // Calculate stats
    final Map<String, int> childStats = {};
    for (var c in children) {
      childStats[c.id] = 0;
    }
    for (var act in activities) {
      if (childStats.containsKey(act.childId)) {
        childStats[act.childId] = childStats[act.childId]! + 1;
      }
    }

    final Map<String, int> typeStats = {};
    for (var t in types) {
      typeStats[t.id] = 0;
    }
    for (var act in activities) {
      if (typeStats.containsKey(act.activityTypeId)) {
        typeStats[act.activityTypeId] = typeStats[act.activityTypeId]! + 1;
      }
    }

    final sortedChildren = children.toList()
      ..sort((a, b) => (childStats[b.id] ?? 0).compareTo(childStats[a.id] ?? 0));
      
    final sortedTypes = types.toList()
      ..sort((a, b) => (typeStats[b.id] ?? 0).compareTo(typeStats[a.id] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Activités',
                    value: '${activities.length}',
                    icon: Icons.auto_graph,
                    color: Colors.blue.shade100,
                    textColor: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Élèves',
                    value: '${children.length}',
                    icon: Icons.people,
                    color: Colors.orange.shade100,
                    textColor: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Palmarès des Élèves (Nb d\'activités)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  final count = childStats[child.id] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
                      child: Text(child.avatarText, style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text('${child.firstname} ${child.lastname ?? ""}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E9F3D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D))),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text('Activités les plus populaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  final count = typeStats[actType.id] ?? 0;
                  if (count == 0) return const SizedBox.shrink(); // Hide 0 count
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                      child: const Icon(Icons.palette, color: Colors.white, size: 18),
                    ),
                    title: Text(actType.name),
                    subtitle: Text(actType.category),
                    trailing: Text('$count fois', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
            backgroundColor: Colors.white,
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
