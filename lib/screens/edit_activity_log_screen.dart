import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../widgets/voice_note_field.dart';

class EditActivityLogScreen extends StatefulWidget {
  final ActivityLog activityLog;
  final ActivityType actType;
  final Child child;

  const EditActivityLogScreen({
    super.key,
    required this.activityLog,
    required this.actType,
    required this.child,
  });

  @override
  State<EditActivityLogScreen> createState() => _EditActivityLogScreenState();
}

class _EditActivityLogScreenState extends State<EditActivityLogScreen> {
  late TextEditingController _noteController;
  String? _evaluationStatusId;
  late String? _audioPath;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.activityLog.note);
    _evaluationStatusId = widget.activityLog.evaluationStatusId;
    _audioPath = widget.activityLog.audioPath;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final space = provider.spaces.firstWhere(
      (s) => s.id == widget.actType.spaceId,
      orElse: () => Space(id: '', name: 'Espace non défini', colorHex: '#718096'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier l\'observation'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Supprimer',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer l\'observation ?'),
                  content: const Text('Vous pourrez annuler juste après la suppression.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    TextButton(
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        final removed = provider.deleteActivityLog(widget.activityLog.id);
                        Navigator.pop(context); // close alert
                        Navigator.pop(context); // close edit screen
                        if (removed != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Observation supprimée'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 8),
                              action: SnackBarAction(
                                label: 'Annuler',
                                textColor: Colors.white,
                                onPressed: () => provider.restoreActivityLog(removed),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
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
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(int.parse(widget.child.colorHex.replaceFirst('#', '0xff'))),
                          child: Text(
                            widget.child.firstname.isNotEmpty ? widget.child.firstname[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.child.firstname} ${widget.child.lastname ?? ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (widget.child.group != null && widget.child.group!.isNotEmpty)
                              Text('Groupe : ${widget.child.group}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(int.parse(space.colorHex.replaceFirst('#', '0xff'))).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '📍 ${space.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(int.parse(space.colorHex.replaceFirst('#', '0xff'))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🎯 ${widget.actType.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📅 ${DateFormat('dd/MM/yyyy à HH:mm').format(widget.activityLog.timestamp)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Statut d\'évaluation${provider.evaluationStatuses.isNotEmpty ? ' *' : ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.evaluationStatuses.map((status) {
                final isSelected = _evaluationStatusId == status.id;
                final couleur = Color(int.parse(status.colorHex.replaceFirst('#', '0xff')));
                return ChoiceChip(
                  label: Text(status.label),
                  selected: isSelected,
                  selectedColor: couleur.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? couleur : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  // Un statut ne peut qu'etre remplace par un autre, pas retire :
                  // une observation doit toujours en porter un.
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() => _evaluationStatusId = status.id);
                  },
                );
              }).toList(),
            ),
            if (_evaluationStatusId == null && provider.evaluationStatuses.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Requis pour enregistrer', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            const SizedBox(height: 24),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes / Observations de l\'enseignant',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            VoiceNoteField(
              provider: provider,
              audioPath: _audioPath,
              onChanged: (path) => setState(() => _audioPath = path),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (provider.evaluationStatuses.isEmpty || _evaluationStatusId != null)
                    ? () {
                  // copyWith plutot qu'une reconstruction champ par champ :
                  // c'est ainsi que les legendes de photos etaient perdues.
                  final updated = widget.activityLog.copyWith(
                    evaluationStatusId: _evaluationStatusId,
                    note: _noteController.text.trim(),
                    audioPath: _audioPath,
                  );
                  provider.updateActivityLog(updated);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Observation mise à jour ✅'), backgroundColor: Color(0xFF4E9F3D)),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer les modifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
