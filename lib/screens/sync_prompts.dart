import 'package:flutter/material.dart';

import '../providers/cloud_sync_controller.dart';
import '../services/icloud_sync.dart';
import '../services/sync_merge.dart';
import '../services/sync_service.dart';
import 'sync_confirm_screen.dart';
import 'sync_conflicts_screen.dart';

/// Apercu obligatoire avant d'ecrire : true pour synchroniser.
Future<bool> confirmSyncChanges(BuildContext context, SyncSummary preview) async {
  if (!context.mounted) return false;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => SyncConfirmScreen(preview: preview)),
  );
  return ok ?? false;
}

/// Choix champ par champ pour les elements modifies des deux cotes.
Future<Map<String, Object?>?> resolveSyncConflicts(BuildContext context,
    List<MergeConflict> conflicts, String peerName, Map<String, dynamic> merged) async {
  if (!context.mounted) return null;
  return Navigator.push<Map<String, Object?>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          SyncConflictsScreen(conflicts: conflicts, peerName: peerName, snapshot: merged),
    ),
  );
}

/// Synchronisation iCloud avec choix et confirmation, puis message du resultat.
Future<void> syncICloudInteractively(BuildContext context, CloudSyncController cloud) async {
  final outcome = await cloud.syncInteractive(
    resolveConflicts: (c, peer, merged) => resolveSyncConflicts(context, c, peer, merged),
    confirmChanges: (preview) => confirmSyncChanges(context, preview),
  );
  if (!context.mounted || outcome == null) return;
  final text = switch (outcome.status) {
    CloudSyncStatus.synced => 'Synchronisé avec iCloud.',
    CloudSyncStatus.upToDate => 'Déjà à jour avec iCloud.',
    _ => outcome.message ?? 'Synchronisation iCloud non terminée.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Fenetre affichee quand la synchronisation automatique attend une decision
/// (suppressions nombreuses ou modifications des deux cotes) : au lieu
/// d'attendre en silence, on previent et on propose de verifier tout de suite.
Future<void> promptPendingCloudSync(BuildContext context, CloudSyncController cloud) async {
  final outcome = cloud.lastOutcome;
  if (outcome == null) return;
  final summary = outcome.summary;
  final deletions = summary?.changes.where((c) => c.kind == ChangeKind.deleted).length ?? 0;
  final conflicts = outcome.status == CloudSyncStatus.needsResolution;
  final verify = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(conflicts ? Icons.call_split : Icons.delete_sweep,
          color: const Color(0xFFB26A00)),
      title: const Text('Synchronisation en attente'),
      content: Text(conflicts
          ? 'Des éléments ont été modifiés à la fois ici et sur un autre appareil. '
              'Choisissez ce qu\'il faut garder ; rien n\'est modifié d\'ici là.'
          : '$deletions élément(s) seraient supprimés par la synchronisation iCloud. '
              'Vérifiez avant de continuer ; rien n\'est modifié d\'ici là.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vérifier')),
      ],
    ),
  );
  if (verify == true && context.mounted) await syncICloudInteractively(context, cloud);
}
