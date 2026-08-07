import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final activities = provider.activities;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Activités enregistrées aujourd\'hui',
                  value: '${activities.length}',
                  icon: Icons.bolt,
                  color: const Color(0xFFFFF3E0),
                  textColor: const Color(0xFFE65100),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fil d\'actualité du jour',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Saisie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Timeline List
          activities.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Aucune activité enregistrée pour le moment.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final act = activities[index];
                    final child = provider.children.firstWhere(
                      (c) => c.id == act.childId,
                      orElse: () => provider.children.first,
                    );
                    final actType = provider.activityTypes.firstWhere(
                      (a) => a.id == act.activityTypeId,
                      orElse: () => provider.activityTypes.first,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                              child: const Icon(Icons.palette, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${child.firstname} ${child.lastname ?? ""}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        act.emotion,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFFFF7043), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    actType.name,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF718096)),
                                  ),
                                  if (act.note != null && act.note!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAF7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        act.note!,
                                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required Color textColor}) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}
