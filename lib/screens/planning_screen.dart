import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../models/planning_slot.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';
import '../utils/pdf_text.dart';
import '../utils/pdf_viewer.dart';

const _dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

/// Planning de la semaine : pour chaque jour, quels groupes font quels
/// ateliers. Scan & Go et le plan de travail s'en servent.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  late DateTime _monday = DateTime.parse(PlanningSlot.weekOf(DateTime.now()));

  String get _week => PlanningSlot.weekOf(_monday);
  String _id() => 'plan_${DateTime.now().microsecondsSinceEpoch}';

  /// Cibles possibles : toute la classe, chaque section, chaque groupe.
  List<String> _targets(AppStateProvider app) => [
        PlanningSlot.allClass,
        for (final s in {for (final c in app.children) if (c.group != null && c.group!.isNotEmpty) c.group!}) 'section:$s',
        for (final g in app.needGroups) 'group:${g.id}',
      ];

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final slots = app.planningForWeek(_week);
    final df = DateFormat('dd/MM');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Rotation des groupes',
            onPressed: () => _rotation(app),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Imprimer la semaine',
            onPressed: slots.isEmpty
                ? null
                : () => openPdfViewer(
                      context,
                      title: 'Planning',
                      fileName: 'Planning_$_week.pdf',
                      build: (f) => _pdf(app, slots, f),
                    ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Semaine précédente',
              onPressed: () => setState(() => _monday = _monday.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Text('Semaine du ${df.format(_monday)}',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Semaine suivante',
              onPressed: () => setState(() => _monday = _monday.add(const Duration(days: 7))),
            ),
          ]),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Reprendre la semaine précédente'),
              onPressed: () {
                final prev = app.planningForWeek(PlanningSlot.weekOf(_monday.subtract(const Duration(days: 7))));
                if (prev.isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('La semaine précédente est vide.')));
                  return;
                }
                for (final s in prev) {
                  app.savePlanningSlot(PlanningSlot(
                      id: _id(), week: _week, day: s.day, target: s.target, atelierIds: s.atelierIds));
                }
              },
            ),
          ),
          for (var day = 1; day <= 5; day++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          '${_dayNames[day - 1]} ${df.format(_monday.add(Duration(days: day - 1)))}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                      onPressed: () => _edit(app, PlanningSlot(id: _id(), week: _week, day: day, target: PlanningSlot.allClass), isNew: true),
                    ),
                  ]),
                  for (final s in slots.where((s) => s.day == day))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups, size: 20),
                      title: Text(app.planningTargetLabel(s.target), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Wrap(spacing: 4, runSpacing: 4, children: [
                        for (final id in s.atelierIds)
                          if (app.activityTypeById(id) case final a?)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: CircleAvatar(backgroundColor: hexToColor(a.colorHex), radius: 6),
                              label: Text(a.name, style: const TextStyle(fontSize: 12)),
                            ),
                      ]),
                      onTap: () => _edit(app, s),
                    ),
                  if (!slots.any((s) => s.day == day))
                    const Text('Rien de prévu.', style: TextStyle(color: kMutedTextColor, fontSize: 12)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(AppStateProvider app, PlanningSlot slot, {bool isNew = false}) async {
    var target = slot.target;
    var ids = List<String>.from(slot.atelierIds);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('${_dayNames[slot.day - 1]} : ${isNew ? 'nouveau créneau' : 'créneau'}'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _targets(app).contains(target) ? target : PlanningSlot.allClass,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pour', border: OutlineInputBorder()),
                items: [
                  for (final t in _targets(app)) DropdownMenuItem(value: t, child: Text(app.planningTargetLabel(t))),
                ],
                onChanged: (v) => setSt(() => target = v ?? target),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('${ids.length} atelier(s)', style: const TextStyle(fontWeight: FontWeight.bold))),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Choisir'),
                  onPressed: () async {
                    final picked = await showAtelierMultiPicker(ctx, app, initial: ids.toSet());
                    if (picked != null) setSt(() => ids = picked);
                  },
                ),
              ]),
              Text([for (final id in ids) app.activityTypeById(id)?.name ?? '?'].join(', '),
                  style: const TextStyle(color: kMutedTextColor)),
            ]),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: ids.isEmpty ? null : () => Navigator.pop(ctx, 'save'), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (result == 'delete') app.deletePlanningSlot(slot.id);
    if (result == 'save') app.savePlanningSlot(slot.copyWith(target: target, atelierIds: ids));
  }

  /// Rotation : chaque groupe passe d'un atelier au suivant, jour apres jour.
  Future<void> _rotation(AppStateProvider app) async {
    final targets = <String>{};
    var ids = <String>[];
    final days = <int>{1, 2, 4, 5};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Rotation des groupes'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chaque groupe fait un atelier par jour et passe au suivant le jour d\'après.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                const SizedBox(height: 10),
                const Text('Groupes', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in _targets(app).where((t) => t != PlanningSlot.allClass))
                    FilterChip(
                      label: Text(app.planningTargetLabel(t)),
                      selected: targets.contains(t),
                      onSelected: (s) => setSt(() => s ? targets.add(t) : targets.remove(t)),
                    ),
                ]),
                const SizedBox(height: 10),
                const Text('Jours', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(spacing: 6, children: [
                  for (var d = 1; d <= 5; d++)
                    FilterChip(
                      label: Text(_dayNames[d - 1]),
                      selected: days.contains(d),
                      onSelected: (s) => setSt(() => s ? days.add(d) : days.remove(d)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text('${ids.length} atelier(s)', style: const TextStyle(fontWeight: FontWeight.bold))),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Choisir'),
                    onPressed: () async {
                      final picked = await showAtelierMultiPicker(ctx, app, initial: ids.toSet());
                      if (picked != null) setSt(() => ids = picked);
                    },
                  ),
                ]),
                Text([for (final id in ids) app.activityTypeById(id)?.name ?? '?'].join(', '),
                    style: const TextStyle(color: kMutedTextColor)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: targets.isEmpty || ids.isEmpty || days.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ordered = targets.toList();
    final dayList = days.toList()..sort();
    for (final (k, day) in dayList.indexed) {
      for (final (g, t) in ordered.indexed) {
        app.savePlanningSlot(PlanningSlot(
            id: _id(), week: _week, day: day, target: t, atelierIds: [ids[(g + k) % ids.length]]));
      }
    }
  }

  Future<Uint8List> _pdf(AppStateProvider app, List<PlanningSlot> slots, PdfPageFormat format) async {
    final targets = <String>[];
    for (final s in slots) {
      if (!targets.contains(s.target)) targets.add(s.target);
    }
    final days = [for (var d = 1; d <= 5; d++) if (slots.any((s) => s.day == d)) d];
    final df = DateFormat('dd/MM');
    pw.Widget cell(String t, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(pdfSafe(t), style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null)),
        );
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: format.landscape,
      build: (_) => [
        pw.Text(pdfSafe('Planning - semaine du ${DateFormat('dd/MM/yyyy').format(_monday)}'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(pdfSafe(app.classSettings.name), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
              cell('', bold: true),
              for (final d in days) cell('${_dayNames[d - 1]} ${df.format(_monday.add(Duration(days: d - 1)))}', bold: true),
            ]),
            for (final t in targets)
              pw.TableRow(children: [
                cell(app.planningTargetLabel(t), bold: true),
                for (final d in days)
                  cell([
                    for (final s in slots.where((s) => s.target == t && s.day == d))
                      for (final id in s.atelierIds) app.activityTypeById(id)?.name ?? '',
                  ].join('\n')),
              ]),
          ],
        ),
      ],
    ));
    return doc.save();
  }
}

/// Choix de plusieurs ateliers ou etapes, ranges par espace et par parcours,
/// avec recherche.
Future<List<String>?> showAtelierMultiPicker(BuildContext context, AppStateProvider app, {Set<String> initial = const {}}) {
  final sel = <String>[...initial];
  var query = '';
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      bool match(ActivityType a) => query.isEmpty || a.name.toLowerCase().contains(query.toLowerCase());
      Widget tile(ActivityType a, {String? prefix}) => CheckboxListTile(
            dense: true,
            value: sel.contains(a.id),
            title: Text(prefix == null ? a.name : '$prefix ${a.name}'),
            onChanged: (v) => setSt(() => v == true ? sel.add(a.id) : sel.remove(a.id)),
          );
      return AlertDialog(
        title: const Text('Ateliers'),
        content: SizedBox(
          width: 440,
          height: 460,
          child: Column(children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher', isDense: true),
              onChanged: (v) => setSt(() => query = v),
            ),
            Expanded(
              child: ListView(children: [
                for (final sp in app.spaces)
                  if (app.ateliersInSpace(sp.id).where(match).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(sp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final a in app.ateliersInSpace(sp.id).where(match)) tile(a),
                  ],
                for (final p in app.progressions)
                  if (app.ateliersInProgressionOrdered(p.id).where(match).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Parcours · ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final (i, a) in app.ateliersInProgressionOrdered(p.id).indexed)
                      if (match(a)) tile(a, prefix: '${i + 1}.'),
                  ],
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, sel), child: const Text('Valider')),
        ],
      );
    }),
  );
}
