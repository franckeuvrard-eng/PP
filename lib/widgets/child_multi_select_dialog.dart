import 'package:flutter/material.dart';
import '../models/child.dart';

/// Selection d'un ou plusieurs eleves, pour une action en masse (rapport,
/// export...). Calque sur le dialogue "Autres eleves concernes" du scan
/// express (qr_scanner_screen.dart).
Future<List<Child>?> showChildMultiSelectDialog(
  BuildContext context, {
  required List<Child> children,
  Set<String>? initialSelection,
}) {
  final selection = Set<String>.from(initialSelection ?? const {});
  return showDialog<List<Child>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setSt) => AlertDialog(
        title: const Text('Choisir les élèves'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setSt(() {
                    if (selection.length == children.length) {
                      selection.clear();
                    } else {
                      selection
                        ..clear()
                        ..addAll(children.map((c) => c.id));
                    }
                  }),
                  child: Text(selection.length == children.length ? 'Tout désélectionner' : 'Tout sélectionner'),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    children: children
                        .map((c) => CheckboxListTile(
                              dense: true,
                              value: selection.contains(c.id),
                              activeColor: const Color(0xFF4E9F3D),
                              title: Text('${c.firstname} ${c.lastname ?? ''}'.trim()),
                              subtitle: c.group == null || c.group!.isEmpty
                                  ? null
                                  : Text(c.group!, style: const TextStyle(fontSize: 12)),
                              onChanged: (checked) => setSt(() {
                                if (checked == true) {
                                  selection.add(c.id);
                                } else {
                                  selection.remove(c.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: selection.isEmpty
                ? null
                : () => Navigator.pop(
                      dialogContext,
                      children.where((c) => selection.contains(c.id)).toList(),
                    ),
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
}
