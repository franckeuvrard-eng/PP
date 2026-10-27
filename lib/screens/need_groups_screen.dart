import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/child.dart';
import '../models/need_group.dart';
import '../providers/app_provider.dart';
import '../services/need_group_suggestions.dart';
import '../utils/color_utils.dart';
import '../widgets/child_multi_select_dialog.dart';
import '../widgets/color_swatch_picker.dart';

/// Groupes de besoin : suggestions tirees des observations, et groupes
/// enregistres (crees a la main ou depuis une suggestion).
class NeedGroupsScreen extends StatelessWidget {
  const NeedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Groupes de besoin'),
          bottom: TabBar(tabs: [
            const Tab(icon: Icon(Icons.auto_awesome), text: 'Suggestions'),
            Tab(icon: const Icon(Icons.groups), text: 'Mes groupes (${provider.needGroups.length})'),
          ]),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            heroTag: 'fab_groupes',
            onPressed: () => editNeedGroup(context, provider),
            icon: const Icon(Icons.group_add),
            label: const Text('Nouveau groupe'),
          ),
        ),
        body: TabBarView(children: [
          _Suggestions(provider: provider),
          _Saved(provider: provider),
        ]),
      ),
    );
  }
}

String _names(List<Child> children) => children.map((c) => c.firstname).join(', ');

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.provider});
  final AppStateProvider provider;

  @override
  Widget build(BuildContext context) {
    final list = NeedGroupSuggestions.suggest(provider);
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pas de suggestion pour l\'instant : elles apparaissent quand au moins deux élèves '
            'sont arrivés à la même étape d\'un parcours, ou au même niveau sur un atelier.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMutedTextColor),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final s in list)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: hexToColor(s.colorHex).withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(s.detail, style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
                  const SizedBox(height: 6),
                  Text(_names(s.children)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: const Text('Enregistrer le groupe'),
                      onPressed: () => editNeedGroup(
                        context,
                        provider,
                        initial: NeedGroup(
                          id: 'grp_${DateTime.now().microsecondsSinceEpoch}',
                          name: s.title,
                          colorHex: s.colorHex,
                          childIds: [for (final c in s.children) c.id],
                          note: s.detail,
                        ),
                        isNew: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.provider});
  final AppStateProvider provider;

  @override
  Widget build(BuildContext context) {
    final groups = provider.needGroups;
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun groupe enregistré. Créez-en un, ou enregistrez une suggestion.',
              textAlign: TextAlign.center, style: TextStyle(color: kMutedTextColor)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final g in groups)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: hexToColor(g.colorHex),
                child: Text('${g.childIds.length}', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                [
                  _names([for (final id in g.childIds) if (provider.childById(id) case final c?) c]),
                  if (g.note != null && g.note!.isNotEmpty) g.note!,
                ].join('\n'),
              ),
              isThreeLine: g.note != null && g.note!.isNotEmpty,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Supprimer le groupe',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Supprimer « ${g.name} » ?'),
                      content: const Text('Les élèves et leurs observations ne sont pas touchés.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) provider.deleteNeedGroup(g.id);
                },
              ),
              onTap: () => editNeedGroup(context, provider, initial: g),
            ),
          ),
      ],
    );
  }
}

/// Creation / modification d'un groupe : nom, couleur, eleves.
Future<void> editNeedGroup(
  BuildContext context,
  AppStateProvider provider, {
  NeedGroup? initial,
  bool isNew = false,
}) async {
  final creating = initial == null || isNew;
  var group = initial ??
      NeedGroup(id: 'grp_${DateTime.now().microsecondsSinceEpoch}', name: '', colorHex: '#7E57C2');
  final nameCtrl = TextEditingController(text: group.name);
  final saved = await showDialog<NeedGroup>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(creating ? 'Nouveau groupe' : 'Modifier le groupe'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du groupe', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ColorSwatchPicker(selectedHex: group.colorHex, onChanged: (hex) => setSt(() => group = group.copyWith(colorHex: hex))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Text('${group.childIds.length} élève(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Choisir'),
                    onPressed: () async {
                      final picked = await showChildMultiSelectDialog(
                        ctx,
                        children: provider.children,
                        initialSelection: group.childIds.toSet(),
                      );
                      if (picked != null) setSt(() => group = group.copyWith(childIds: [for (final c in picked) c.id]));
                    },
                  ),
                ]),
                Text(
                  _names([for (final id in group.childIds) if (provider.childById(id) case final c?) c]),
                  style: const TextStyle(color: kMutedTextColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty || group.childIds.isEmpty) return;
              Navigator.pop(ctx, group.copyWith(name: name));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  nameCtrl.dispose();
  if (saved == null) return;
  provider.saveNeedGroup(saved);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Groupe « ${saved.name} » enregistré.')));
  }
}
