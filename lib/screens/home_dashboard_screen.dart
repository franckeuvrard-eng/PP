import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../utils/app_icons.dart';
import 'statistics_screen.dart';
import 'edit_activity_log_screen.dart';
import '../widgets/voice_note_play_button.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  Widget _buildChildAvatar(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    if (absolutePath != null && File(absolutePath).existsSync()) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: FileImage(File(absolutePath)),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
      child: Text(
        child.avatarText,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final activities = provider.activities;
    final now = DateTime.now();
    final todayActivities = activities.where((a) => a.timestamp.year == now.year && a.timestamp.month == now.month && a.timestamp.day == now.day).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.loadFailed) const _LoadFailureBanner(),

          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Aujourd\'hui',
                  value: '${todayActivities.length}',
                  icon: Icons.bolt,
                  color: isDark ? const Color(0xFF3B2E15) : const Color(0xFFFFF3E0),
                  textColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                  },
                  child: _buildStatCard(
                    title: 'Statistiques',
                    value: 'Analyses',
                    icon: Icons.bar_chart,
                    color: isDark ? const Color(0xFF1A2744) : const Color(0xFFE3F2FD),
                    textColor: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fil d\'actualité du jour',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Timeline List
          todayActivities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'Aucune activité enregistrée aujourd\'hui.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayActivities.length,
                  itemBuilder: (context, index) {
                    final act = todayActivities[index];
                    // Resolution par index : trois balayages lineaires par
                    // ligne du fil, a chaque reconstruction, sinon.
                    final child = provider.childById(act.childId) ??
                        Child(id: '', firstname: 'Élève inconnu', colorHex: '#718096', avatarText: '?');
                    final actType = provider.activityTypeById(act.activityTypeId) ??
                        ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: '#718096');
                    final space = provider.spaceById(actType.spaceId) ??
                        Space(id: '', name: '', colorHex: '#718096');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Workshop/Activity icon or cover image if exists
                            (actType.imagePath != null &&
                                    provider.getAbsolutePath(actType.imagePath) != null &&
                                    File(provider.getAbsolutePath(actType.imagePath)!).existsSync())
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(provider.getAbsolutePath(actType.imagePath)!),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: Color(int.parse(actType.colorHex.replaceFirst('#', '0xff'))),
                                    child: Icon(iconForName(actType.iconName, fallback: Icons.palette),
                                        color: Colors.white),
                                  ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Child info & Edit button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          _buildChildAvatar(child, provider),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${child.firstname} ${child.lastname ?? ""}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Éditer l\'observation',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditActivityLogScreen(
                                                activityLog: act,
                                                actType: actType,
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Activity Type, Space, Obligatory & Time
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '🎯 ${actType.name}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      if (space.name.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4E9F3D).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '📍 ${space.name}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                                          ),
                                        ),
                                      if (actType.isObligatoryForGroup(child.group))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '⭐ Obligatoire',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                          ),
                                        ),
                                      Text(
                                        '• ${DateFormat('HH:mm').format(act.timestamp)}',
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                      ),
                                    ],
                                  ),
                                  
                                  // Evaluation Status pill
                                  if (provider.statusLabel(act) != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        provider.statusLabel(act)!,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                    ),
                                  ],

                                  // Observation Note
                                  if (act.note != null && act.note!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                      ),
                                      child: Text(
                                        act.note!,
                                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                      ),
                                    ),
                                  ],

                                  // Voice note
                                  if (act.audioPath != null && act.audioPath!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    VoiceNotePlayButton(provider: provider, audioPath: act.audioPath!),
                                  ],

                                  // Attached Photo Gallery Carousel
                                  if (act.photoPaths.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 90,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: act.photoPaths.length,
                                        itemBuilder: (context, photoIndex) {
                                          final path = act.photoPaths[photoIndex];
                                          final resolvedPath = provider.getAbsolutePath(path);
                                          if (resolvedPath == null || !File(resolvedPath).existsSync()) return const SizedBox();
                                          return GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => Dialog(
                                                  backgroundColor: Colors.transparent,
                                                  insetPadding: const EdgeInsets.all(10),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      InteractiveViewer(
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(16),
                                                          child: Image.file(File(resolvedPath), fit: BoxFit.contain),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        top: 10,
                                                        right: 10,
                                                        child: CircleAvatar(
                                                          backgroundColor: Colors.black54,
                                                          child: IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.white),
                                                            onPressed: () => Navigator.pop(context),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.file(
                                                  File(resolvedPath),
                                                  width: 90,
                                                  height: 90,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required Color textColor, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            // Pastille teintee en mode sombre : un cercle blanc franc sur la
            // carte sombre etait trop contraste.
            backgroundColor: isDark ? textColor.withOpacity(0.18) : Colors.white,
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

/// Alerte affichee quand la relecture des donnees a echoue.
///
/// La classe est alors volontairement vide : le risque n'est pas de ne rien
/// voir, c'est de saisir une journee d'observations par-dessus des donnees
/// qui n'ont pas ete chargees, et de la perdre a la restauration.
class _LoadFailureBanner extends StatelessWidget {
  const _LoadFailureBanner();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Données non chargées',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos élèves et observations n\'ont pas pu être relus. Ne saisissez '
            'rien pour l\'instant : restaurez une sauvegarde depuis Paramètres > '
            'Sauvegarde & Sécurité, ou réessayez.',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () async {
                await provider.initialize();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.loadFailed
                        ? 'Les données restent illisibles.'
                        : 'Données rechargées.'),
                    backgroundColor:
                        provider.loadFailed ? Colors.red : const Color(0xFF4E9F3D),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
