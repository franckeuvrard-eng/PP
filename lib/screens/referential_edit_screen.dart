import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/referential.dart';
import '../providers/app_provider.dart';

/// Création ou modification d'un référentiel : son nom, ses groupes et les
/// items de chaque groupe. Rien n'est pré-rempli : le contenu vient
/// entièrement de l'enseignant.
class ReferentialEditScreen extends StatefulWidget {
  final Referential? referential;

  const ReferentialEditScreen({super.key, this.referential});

  @override
  State<ReferentialEditScreen> createState() => _ReferentialEditScreenState();
}

class _ReferentialEditScreenState extends State<ReferentialEditScreen> {
  late final TextEditingController _nameController;
  late List<ReferentialGroup> _groups;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.referential?.name ?? '');
    _groups = List<ReferentialGroup>.from(widget.referential?.groups ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addOrRenameGroup({ReferentialGroup? group}) async {
    final ctrl = TextEditingController(text: group?.title ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(group == null ? 'Nouveau groupe' : 'Renommer le groupe'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom du groupe',
            hintText: 'Ceinture blanche, Vie pratique...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      if (group == null) {
        _groups = [
          ..._groups,
          ReferentialGroup(id: 'group_${DateTime.now().millisecondsSinceEpoch}', title: result),
        ];
      } else {
        final index = _groups.indexWhere((g) => g.id == group.id);
        if (index >= 0) {
          _groups[index] = ReferentialGroup(id: group.id, title: result, items: group.items);
        }
      }
    });
  }

  void _deleteGroup(ReferentialGroup group) {
    setState(() => _groups = _groups.where((g) => g.id != group.id).toList());
  }

  Future<void> _addOrRenameItem(ReferentialGroup group, {ReferentialItem? item}) async {
    final ctrl = TextEditingController(text: item?.label ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Nouvel item' : 'Renommer l\'item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Libellé de l\'item',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      final groupIndex = _groups.indexWhere((g) => g.id == group.id);
      if (groupIndex < 0) return;
      final items = List<ReferentialItem>.from(_groups[groupIndex].items);
      if (item == null) {
        items.add(ReferentialItem(id: 'item_${DateTime.now().millisecondsSinceEpoch}', label: result));
      } else {
        final itemIndex = items.indexWhere((i) => i.id == item.id);
        if (itemIndex >= 0) items[itemIndex] = ReferentialItem(id: item.id, label: result);
      }
      _groups[groupIndex] = ReferentialGroup(id: group.id, title: group.title, items: items);
    });
  }

  void _deleteItem(ReferentialGroup group, ReferentialItem item) {
    setState(() {
      final groupIndex = _groups.indexWhere((g) => g.id == group.id);
      if (groupIndex < 0) return;
      final items = group.items.where((i) => i.id != item.id).toList();
      _groups[groupIndex] = ReferentialGroup(id: group.id, title: group.title, items: items);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final referential = Referential(
      id: widget.referential?.id ?? 'referential_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      groups: _groups,
    );
    provider.addOrUpdateReferential(referential);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.referential == null ? 'Nouveau référentiel' : 'Modifier le référentiel'),
        backgroundColor: const Color(0xFF4E9F3D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du référentiel *',
                hintText: 'Ceintures de couleur, Montessori...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Groupes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                TextButton.icon(
                  onPressed: () => _addOrRenameGroup(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter un groupe'),
                ),
              ],
            ),
            if (_groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Un groupe régroupe plusieurs items (ex: une couleur de ceinture, un domaine Montessori).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ..._groups.map((group) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(group.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                              tooltip: 'Renommer le groupe',
                              onPressed: () => _addOrRenameGroup(group: group),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              tooltip: 'Supprimer le groupe',
                              onPressed: () => _deleteGroup(group),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...group.items.map((item) => InputChip(
                                  label: Text(item.label, style: const TextStyle(fontSize: 12)),
                                  onPressed: () => _addOrRenameItem(group, item: item),
                                  onDeleted: () => _deleteItem(group, item),
                                )),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text('Item', style: TextStyle(fontSize: 12)),
                              onPressed: () => _addOrRenameItem(group),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, _) => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: value.text.trim().isEmpty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
