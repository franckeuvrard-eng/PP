import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';

/// Saisies des eleves (mode tablette) a valider : l'adulte donne un niveau
/// d'un geste, ou supprime une saisie erronee.
class PendingValidationScreen extends StatelessWidget {
  const PendingValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final logs = app.pendingLogs;
    final df = DateFormat('dd/MM HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text('À valider (${logs.length})')),
      body: logs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Rien à valider. Les saisies du mode élève arrivent ici.',
                    textAlign: TextAlign.center, style: TextStyle(color: kMutedTextColor)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Touchez le niveau atteint pour valider la saisie.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                const SizedBox(height: 8),
                for (final log in logs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: hexToColor(app.childById(log.childId)?.colorHex ?? '#718096'),
                            child: Text(app.childById(log.childId)?.avatarText ?? '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${app.childById(log.childId)?.firstname ?? 'Élève supprimé'} · '
                              '${app.activityTypeById(log.activityTypeId)?.name ?? 'Atelier supprimé'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(df.format(log.timestamp), style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Supprimer cette saisie',
                            onPressed: () => app.deleteActivityLog(log.id),
                          ),
                        ]),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final s in app.evaluationStatuses)
                            ActionChip(
                              avatar: CircleAvatar(backgroundColor: hexToColor(s.colorHex), radius: 7),
                              label: Text(s.label),
                              onPressed: () => app.validateLog(log.id, s.id),
                            ),
                        ]),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}
