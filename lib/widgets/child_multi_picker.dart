import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/child.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';

/// Liste d'eleves a cocher, avec selection rapide : toute la classe, une
/// section, un groupe de besoin. Partagee par la validation groupee et le
/// depart en cours de parcours.
///
/// Un eleve peut etre grise ([disabledReasonOf] renvoie la raison) : il reste
/// visible, avec l'explication, mais ne se coche pas et n'est jamais pris par
/// une selection rapide.
///
/// A placer dans un defilement fourni par l'appelant (la liste n'a pas de
/// hauteur propre).
class ChildMultiPicker extends StatelessWidget {
  const ChildMultiPicker({
    super.key,
    required this.children,
    required this.selected,
    required this.onChanged,
    this.subtitleOf,
    this.disabledReasonOf,
  });

  final List<Child> children;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Ligne sous le nom (statut actuel, depart...).
  final Widget? Function(Child child)? subtitleOf;

  /// Raison pour laquelle l'eleve ne peut pas etre choisi ; null : il peut.
  final String? Function(Child child)? disabledReasonOf;

  bool _selectable(Child c) => disabledReasonOf?.call(c) == null;

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final selectable = children.where(_selectable).toList();
    final selectableIds = {for (final c in selectable) c.id};

    // Sections presentes dans la liste, dans l'ordre alphabetique.
    final sections = {
      for (final c in children)
        if (c.group != null && c.group!.trim().isNotEmpty) c.group!,
    }.toList()
      ..sort();

    // Ajoute les eleves [ids] a la selection ; s'ils y sont deja tous, les
    // retire : une pastille sert a cocher puis a decocher son groupe.
    void toggleGroup(Iterable<String> ids) {
      final target = ids.where(selectableIds.contains).toSet();
      if (target.isEmpty) return;
      final next = Set<String>.from(selected);
      if (target.every(selected.contains)) {
        next.removeAll(target);
      } else {
        next.addAll(target);
      }
      onChanged(next);
    }

    bool groupFullySelected(Iterable<String> ids) {
      final target = ids.where(selectableIds.contains).toSet();
      return target.isNotEmpty && target.every(selected.contains);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              avatar: const Icon(Icons.groups, size: 16),
              label: const Text('Toute la classe'),
              selected: groupFullySelected(selectableIds),
              onSelected: (_) => toggleGroup(selectableIds),
            ),
            for (final section in sections)
              () {
                final ids = [for (final c in children) if (c.group == section) c.id];
                return FilterChip(
                  label: Text(section),
                  selected: groupFullySelected(ids),
                  onSelected: (_) => toggleGroup(ids),
                );
              }(),
            for (final g in app.needGroups)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: hexToColor(g.colorHex), radius: 6),
                label: Text(g.name),
                selected: groupFullySelected(g.childIds),
                onSelected: (_) => toggleGroup(g.childIds),
              ),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(<String>{}),
                child: const Text('Tout décocher'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final c in children)
          () {
            final reason = disabledReasonOf?.call(c);
            final enabled = reason == null;
            final sub = reason != null
                ? Text(reason, style: const TextStyle(fontSize: 12, color: kMutedTextColor))
                : subtitleOf?.call(c);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: enabled && selected.contains(c.id),
              onChanged: enabled
                  ? (v) {
                      final next = Set<String>.from(selected);
                      v == true ? next.add(c.id) : next.remove(c.id);
                      onChanged(next);
                    }
                  : null,
              secondary: CircleAvatar(
                radius: 16,
                backgroundColor: hexToColor(c.colorHex).withValues(alpha: enabled ? 1 : 0.4),
                child: Text(c.avatarText,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Text('${c.firstname} ${c.lastname ?? ''}'.trim(),
                  style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? null : kMutedTextColor)),
              subtitle: sub,
            );
          }(),
      ],
    );
  }
}
