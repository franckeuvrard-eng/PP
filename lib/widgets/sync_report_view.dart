import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/sync_merge.dart';
import '../services/sync_report.dart';
import '../services/sync_service.dart';
import '../utils/color_utils.dart';

const _green = Color(0xFF4E9F3D);

/// Compte rendu detaille d'une synchronisation : ce qui a change sur cet
/// appareil, puis sur l'autre, categorie par categorie, avec les noms.
class SyncReportView extends StatelessWidget {
  const SyncReportView({
    super.key,
    required this.summary,
    required this.at,
    required this.receivedFromPeer,
  });

  final SyncSummary summary;
  final DateTime at;

  /// Vrai quand c'est l'autre appareil qui a lance la synchronisation.
  final bool receivedFromPeer;

  /// Au-dela, une categorie affiche « … et N autres » (premiere synchro).
  static const _maxLines = 40;

  @override
  Widget build(BuildContext context) {
    final peer = summary.peerName.isEmpty ? 'l’autre appareil' : summary.peerName;
    final here = SyncReport.build(summary.changes, onLocal: true, snapshot: summary.snapshot);
    final there = SyncReport.build(summary.changes, onLocal: false, snapshot: summary.snapshot);
    final media = summary.mediaDownloaded + summary.mediaUploaded;
    final upToDate = here.isEmpty && there.isEmpty && media == 0;
    final time = DateFormat('HH:mm').format(at);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _green.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  upToDate
                      ? 'Déjà à jour avec $peer ($time)'
                      : receivedFromPeer
                          ? 'Synchronisation reçue de $peer à $time'
                          : 'Synchronisé avec $peer à $time',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ]),
            if (upToDate)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Les deux appareils avaient déjà les mêmes données : rien n’a changé.',
                    style: TextStyle(fontSize: 13)),
              )
            else ...[
              _side(context, 'Sur cet appareil', here, received: summary.mediaDownloaded),
              _side(context, 'Sur $peer', there, received: summary.mediaUploaded),
              if (summary.conflicts > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '⚠ ${summary.conflicts} élément(s) avaient été modifiés sur les deux appareils : '
                    'la version choisie sur ${receivedFromPeer ? peer : 'cet appareil'} a été gardée '
                    '(marqués « conflit » ci-dessus).',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB26A00)),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Une sauvegarde a été faite juste avant sur chaque appareil '
                  '(Réglages › Sauvegardes automatiques, « Avant synchronisation »).',
                  style: TextStyle(fontSize: 11, color: kMutedTextColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _side(BuildContext context, String title, List<SyncReportGroup> groups,
      {required int received}) {
    final total = groups.fold<int>(0, (n, g) => n + g.lines.length);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          if (total == 0 && received == 0)
            const Text('Aucun changement.', style: TextStyle(fontSize: 13, color: kMutedTextColor)),
          for (final g in groups)
            Theme(
              // Pas de traits au-dessus/dessous des tuiles depliees.
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
                initiallyExpanded: total <= 8,
                title: Text('${g.title} : ${_counts(g)}', style: const TextStyle(fontSize: 13)),
                children: [
                  for (final l in g.lines.take(_maxLines)) _line(l),
                  if (g.lines.length > _maxLines)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('… et ${g.lines.length - _maxLines} autre(s)',
                          style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
                    ),
                ],
              ),
            ),
          if (received > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Photos et notes vocales : $received reçue(s)',
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  static String _counts(SyncReportGroup g) {
    final parts = [
      if (g.count(ChangeKind.added) > 0) '${g.count(ChangeKind.added)} ajouté(s)',
      if (g.count(ChangeKind.updated) > 0) '${g.count(ChangeKind.updated)} modifié(s)',
      if (g.count(ChangeKind.deleted) > 0) '${g.count(ChangeKind.deleted)} supprimé(s)',
    ];
    return parts.join(', ');
  }

  static Widget _line(SyncReportLine l) {
    final (IconData icon, Color color) = switch (l.kind) {
      ChangeKind.added => (Icons.add_circle_outline, _green),
      ChangeKind.updated => (Icons.edit_outlined, const Color(0xFF1E6FB8)),
      ChangeKind.deleted => (Icons.remove_circle_outline, const Color(0xFFC62828)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.label + (l.conflict ? '  (conflit)' : ''),
              style: TextStyle(
                fontSize: 13,
                decoration: l.kind == ChangeKind.deleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
