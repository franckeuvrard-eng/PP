import 'package:flutter/material.dart';

import '../services/sync_merge.dart';
import '../services/sync_service.dart';
import '../widgets/sync_report_view.dart';

const _red = Color(0xFFB3261E);

/// Apercu obligatoire avant toute ecriture : ce qui va etre ajoute, modifie
/// et supprime sur chacun des deux appareils. Renvoie true pour synchroniser,
/// false (ou retour) pour annuler sans rien modifier.
///
/// Les suppressions sont mises en avant : une synchronisation lancee depuis
/// un appareil vide videait jusqu'ici l'autre sans prevenir.
class SyncConfirmScreen extends StatelessWidget {
  const SyncConfirmScreen({super.key, required this.preview});

  final SyncSummary preview;

  @override
  Widget build(BuildContext context) {
    final peer = preview.peerName.isEmpty ? 'l’autre appareil' : preview.peerName;
    final deletedHere = _deletions(onLocal: true);
    final deletedThere = _deletions(onLocal: false);
    final hasDeletions = deletedHere.total + deletedThere.total > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier avant de synchroniser')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Rien n’est encore modifié. Voici ce que la synchronisation avec $peer va faire '
                'sur chacun des deux appareils.',
                style: const TextStyle(fontSize: 13),
              ),
              if (deletedHere.total > 0) _warning('cet appareil', deletedHere),
              if (deletedThere.total > 0) _warning(peer, deletedThere),
              const SizedBox(height: 12),
              SyncReportView(
                summary: preview,
                at: DateTime.now(),
                receivedFromPeer: false,
                preview: true,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: hasDeletions ? FilledButton.styleFrom(backgroundColor: _red) : null,
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(hasDeletions ? Icons.warning_amber_rounded : Icons.sync),
                label: Text(hasDeletions ? 'Synchroniser quand même' : 'Synchroniser'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  ({int total, int children, int activities}) _deletions({required bool onLocal}) {
    final del = preview.changes
        .where((c) => c.onLocal == onLocal && c.kind == ChangeKind.deleted)
        .toList();
    return (
      total: del.length,
      children: del.where((c) => c.category == 'children').length,
      activities: del.where((c) => c.category == 'activities').length,
    );
  }

  Widget _warning(String where, ({int total, int children, int activities}) d) {
    final details = [
      if (d.children > 0) '${d.children} élève(s)',
      if (d.activities > 0) '${d.activities} observation(s)',
    ].join(', ');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.delete_forever, color: _red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${d.total} élément(s) vont être SUPPRIMÉS sur $where'
              '${details.isEmpty ? '' : ' (dont $details)'}, parce qu’ils ont été supprimés '
              'de l’autre côté depuis la dernière synchronisation.\n'
              'Si ce n’est pas voulu, annulez.',
              style: const TextStyle(fontSize: 13, color: _red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
