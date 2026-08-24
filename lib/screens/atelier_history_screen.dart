import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';
import '../widgets/voice_note_play_button.dart';
import 'edit_activity_log_screen.dart';

/// Historique complet des observations d'un atelier pour un eleve : toutes
/// les dates, statuts, notes, photos et notes vocales, pas seulement le
/// statut le plus recent affiche dans le suivi par atelier.
class AtelierHistoryScreen extends StatelessWidget {
  final Child child;
  final ActivityType atelier;

  const AtelierHistoryScreen({super.key, required this.child, required this.atelier});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, _) {
        final logs = provider
            .activitiesForChild(child.id)
            .where((l) => l.activityTypeId == atelier.id)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
          appBar: AppBar(title: Text('${atelier.name} · ${child.firstname}')),
          body: logs.isEmpty
              ? const Center(child: Text('Aucune observation enregistrée pour cet atelier.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _buildLogCard(context, provider, logs[index]),
                ),
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, AppStateProvider provider, ActivityLog log) {
    final status = provider.statusById(log.evaluationStatusId);
    final color = status != null ? hexToColor(status.colorHex) : Colors.grey;
    final label = provider.statusLabel(log);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditActivityLogScreen(activityLog: log, actType: atelier, child: child),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE dd MMMM yyyy · HH:mm', 'fr_FR').format(log.timestamp),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                ],
              ),
              if (label != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
              if (log.note != null && log.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('📝 ${log.note!}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              if (log.audioPath != null && log.audioPath!.isNotEmpty) ...[
                const SizedBox(height: 6),
                VoiceNotePlayButton(provider: provider, audioPath: log.audioPath!),
              ],
              if (log.photoPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: log.photoPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final absPath = provider.getAbsolutePath(log.photoPaths[i]);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: absPath != null && File(absPath).existsSync()
                            ? Image.file(File(absPath), width: 72, height: 72, fit: BoxFit.cover)
                            : Container(
                                width: 72,
                                height: 72,
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                child: const Icon(Icons.broken_image, size: 20),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
