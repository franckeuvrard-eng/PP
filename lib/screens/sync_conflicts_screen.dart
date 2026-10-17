import 'package:flutter/material.dart';

import '../services/sync_merge.dart';
import '../services/sync_report.dart';
import '../utils/color_utils.dart';

const _green = Color(0xFF4E9F3D);
const _blue = Color(0xFF1E6FB8);

/// Ecran de choix quand des elements ont ete modifies sur les deux appareils.
///
/// Renvoie (via `Navigator.pop`) la valeur a garder par [MergeConflict.id],
/// ou null si l'utilisateur annule : la synchronisation s'arrete alors sans
/// rien modifier. Pour un objet (fiche eleve, observation…), le choix se fait
/// champ par champ ; la version gardee peut donc combiner les deux.
class SyncConflictsScreen extends StatefulWidget {
  const SyncConflictsScreen({
    super.key,
    required this.conflicts,
    required this.peerName,
    required this.snapshot,
  });

  final List<MergeConflict> conflicts;
  final String peerName;

  /// Donnees fusionnees, pour afficher les noms (eleves, ateliers…).
  final Map<String, dynamic> snapshot;

  @override
  State<SyncConflictsScreen> createState() => _SyncConflictsScreenState();
}

class _SyncConflictsScreenState extends State<SyncConflictsScreen> {
  /// Par conflit : champs pris sur l'autre appareil. Pour une valeur simple,
  /// le champ '' represente la valeur entiere. Par defaut : tout garder ici.
  late final List<Set<String>> _fromRemote =
      List.generate(widget.conflicts.length, (_) => <String>{});

  String get _peer => widget.peerName.isEmpty ? 'l’autre appareil' : widget.peerName;

  List<String> _fields(MergeConflict c) {
    final f = c.differingFields;
    return f.isEmpty ? const [''] : f;
  }

  void _setAll(bool remote) {
    setState(() {
      for (var i = 0; i < widget.conflicts.length; i++) {
        _fromRemote[i]
          ..clear()
          ..addAll(remote ? _fields(widget.conflicts[i]) : const []);
      }
    });
  }

  void _validate() {
    final out = <String, Object?>{};
    for (var i = 0; i < widget.conflicts.length; i++) {
      final c = widget.conflicts[i];
      final remote = _fromRemote[i];
      out[c.id] = remote.contains('') ? c.remote : c.combine(remote);
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.conflicts.length;
    return Scaffold(
      appBar: AppBar(title: Text('$n conflit${n > 1 ? 's' : ''} à résoudre')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: n + 1,
            itemBuilder: (context, i) => i == 0 ? _header() : _conflictCard(i - 1),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler la synchro'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _validate,
                icon: const Icon(Icons.check),
                label: const Text('Valider et synchroniser'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ces éléments ont été modifiés à la fois sur cet appareil et sur $_peer '
              'depuis la dernière synchronisation. Pour chaque différence, choisissez '
              'la version à garder : elle sera enregistrée sur les deux appareils.\n'
              'Rien n’est modifié tant que vous n’avez pas validé.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _setAll(false),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Tout garder ici'),
              ),
              OutlinedButton.icon(
                onPressed: () => _setAll(true),
                icon: const Icon(Icons.call_received, size: 18),
                label: Text('Tout prendre de $_peer'),
              ),
            ]),
          ],
        ),
      );

  Widget _conflictCard(int index) {
    final c = widget.conflicts[index];
    final title = SyncReport.describe(c.category, c.key, c.local, widget.snapshot);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SyncReport.categoryTitle(c.category).toUpperCase(),
                style: const TextStyle(fontSize: 11, color: kMutedTextColor, letterSpacing: 0.5)),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            for (final field in _fields(c)) _fieldChoice(index, c, field),
          ],
        ),
      ),
    );
  }

  Widget _fieldChoice(int index, MergeConflict c, String field) {
    String fmt(Object? whole) {
      final v = field.isEmpty ? whole : (whole is Map ? whole[field] : null);
      return SyncReport.formatValue(c.category, field, v, widget.snapshot);
    }

    final remote = _fromRemote[index].contains(field);
    void choose(bool r) => setState(() {
          r ? _fromRemote[index].add(field) : _fromRemote[index].remove(field);
        });

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.isNotEmpty)
            Text(SyncReport.fieldLabel(field),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _option('Cet appareil', fmt(c.local), selected: !remote, color: _green,
              onTap: () => choose(false)),
          const SizedBox(height: 6),
          _option(_peer, fmt(c.remote), selected: remote, color: _blue,
              onTap: () => choose(true)),
        ],
      ),
    );
  }

  Widget _option(String who, String value,
      {required bool selected, required Color color, required VoidCallback onTap}) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$who : $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : Colors.grey.withOpacity(0.4),
                width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18, color: selected ? color : Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(who, style: TextStyle(fontSize: 11, color: color)),
                    Text(value, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
