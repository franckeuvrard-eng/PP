import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/eduscol_data.dart';
import '../models/carnet_entry.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../services/carnet_service.dart';
import '../utils/color_utils.dart';
import '../utils/pdf_viewer.dart';
import '../widgets/child_multi_select_dialog.dart';
import '../widgets/dictation_button.dart';

/// Carnet de suivi des apprentissages : commentaires par periode et
/// synthese de fin d'ecole maternelle, eleve par eleve, puis PDF.
class CarnetScreen extends StatefulWidget {
  const CarnetScreen({super.key, this.synthese = false});

  /// Ouvre directement la synthese de fin de GS.
  final bool synthese;

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen> {
  late bool _synthese = widget.synthese;
  String? _childId;
  late String _period;
  DateTimeRange? _customRange;
  final Map<String, TextEditingController> _ctrls = {};
  String _loadedKey = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppStateProvider>();
    _period = CarnetService.currentPeriod(app.classSettings.schoolYear);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Child> _children(AppStateProvider app) => app.children.toList()
    ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));

  String get _entryPeriod => _synthese ? CarnetEntry.synthese : _period;

  DateTimeRange _range(AppStateProvider app) =>
      _customRange ?? CarnetService.periodRange(app.classSettings.schoolYear, _period);

  /// Champs de texte de l'eleve et de la periode affiches (recrees au
  /// changement).
  void _ensureControllers(AppStateProvider app, Child child) {
    final key = '${child.id}|$_entryPeriod';
    if (key == _loadedKey) return;
    _loadedKey = key;
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    final e = app.carnetFor(child.id, _entryPeriod);
    for (final d in EduscolData.domainsForCycle(1)) {
      _ctrls[d.id] = TextEditingController(text: e.comments[d.id] ?? '');
    }
    _ctrls['strengths'] = TextEditingController(text: e.strengths);
    _ctrls['needs'] = TextEditingController(text: e.needs);
  }

  /// Enregistre les textes, un instant apres la derniere frappe.
  void _scheduleSave(AppStateProvider app, Child child) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _saveTexts(app, child));
  }

  void _saveTexts(AppStateProvider app, Child child) {
    _debounce?.cancel();
    final e = app.carnetFor(child.id, _entryPeriod);
    final comments = {
      for (final d in EduscolData.domainsForCycle(1))
        if ((_ctrls[d.id]?.text.trim() ?? '').isNotEmpty) d.id: _ctrls[d.id]!.text.trim(),
    };
    final strengths = _ctrls['strengths']?.text.trim() ?? '';
    final needs = _ctrls['needs']?.text.trim() ?? '';
    // Rien de change : pas d'enregistrement (ni de saisie vide creee en
    // passant d'un eleve a l'autre).
    final same = strengths == e.strengths &&
        needs == e.needs &&
        comments.length == e.comments.length &&
        comments.entries.every((x) => e.comments[x.key] == x.value);
    if (same) return;
    app.saveCarnet(e.copyWith(comments: comments, strengths: strengths, needs: needs));
  }

  void _openPdf(AppStateProvider app, List<Child> children) {
    final range = _range(app);
    openPdfViewer(
      context,
      title: _synthese ? 'Synthèse de fin de maternelle' : 'Carnet de suivi - $_period',
      fileName: _synthese
          ? 'Synthese_fin_maternelle.pdf'
          : 'Carnet_${_period}_${children.length == 1 ? children.first.firstname : 'eleves'}.pdf'.replaceAll(' ', '_'),
      build: (format) => _synthese
          ? CarnetService.buildSyntheseBytes(provider: app, children: children, format: format)
          : CarnetService.buildCarnetBytes(
              provider: app, children: children, period: _period, range: range, format: format),
      shareSubject: _synthese ? 'Synthèse des acquis' : 'Carnet de suivi',
      shareEmails: children.length == 1 && children.first.parentEmails.isNotEmpty
          ? children.first.parentEmails
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final children = _children(app);
    if (children.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carnet de suivi')),
        body: const Center(child: Text('Aucun élève.')),
      );
    }
    final child = children.firstWhere((c) => c.id == _childId, orElse: () => children.first);
    final index = children.indexOf(child);
    _ensureControllers(app, child);

    void go(int delta) {
      _saveTexts(app, child);
      setState(() => _childId = children[(index + delta) % children.length].id);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_synthese ? 'Synthèse de fin de maternelle' : 'Carnet de suivi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF de cet élève',
            onPressed: () {
              _saveTexts(app, child);
              _openPdf(app, [child]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'PDF de plusieurs élèves',
            onPressed: () async {
              _saveTexts(app, child);
              final picked = await showChildMultiSelectDialog(context,
                  children: children, initialSelection: {for (final c in children) c.id});
              if (picked != null && picked.isNotEmpty && mounted) _openPdf(app, picked);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.menu_book), label: Text('Carnet de période')),
              ButtonSegment(value: true, icon: Icon(Icons.fact_check), label: Text('Synthèse fin GS')),
            ],
            selected: {_synthese},
            onSelectionChanged: (s) {
              _saveTexts(app, child);
              setState(() => _synthese = s.first);
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Élève précédent', onPressed: () => go(-1)),
            Expanded(
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: child.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Élève', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final c in children)
                    DropdownMenuItem(value: c.id, child: Text('${c.firstname} ${c.lastname ?? ''}'.trim())),
                ],
                onChanged: (id) {
                  _saveTexts(app, child);
                  setState(() => _childId = id);
                },
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Élève suivant', onPressed: () => go(1)),
          ]),
          const SizedBox(height: 12),
          if (_synthese) ..._syntheseBody(app, child) else ..._periodBody(app, child),
        ],
      ),
    );
  }

  List<Widget> _periodBody(AppStateProvider app, Child child) {
    final range = _range(app);
    final data = CarnetService.byDomain(app, child, range);
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in CarnetService.periods)
          ChoiceChip(
            label: Text('Période ${p.substring(1)}'),
            selected: _period == p,
            onSelected: (_) {
              _saveTexts(app, child);
              setState(() {
                _period = p;
                _customRange = null;
              });
            },
          ),
      ]),
      TextButton.icon(
        icon: const Icon(Icons.date_range, size: 18),
        label: Text('Du ${DateFormat('dd/MM/yyyy').format(range.start)} au ${DateFormat('dd/MM/yyyy').format(range.end)}'),
        onPressed: () async {
          final r = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDateRange: range,
            locale: const Locale('fr', 'FR'),
          );
          if (r != null) setState(() => _customRange = r);
        },
      ),
      const Text(
        'Réussites : la dernière observation de chaque atelier, au niveau le plus abouti (ou étape validée). '
        'Elles figurent dans le PDF avec leurs photos.',
        style: TextStyle(fontSize: 12, color: kMutedTextColor),
      ),
      const SizedBox(height: 8),
      for (final d in EduscolData.domainsForCycle(1))
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: TextStyle(fontWeight: FontWeight.bold, color: hexToColor(d.colorHex))),
              const SizedBox(height: 4),
              Text(
                [
                  'Réussites : ${data[d.id]?.done.length ?? 0}',
                  if ((data[d.id]?.done ?? const []).isNotEmpty)
                    data[d.id]!.done.map((i) => i.atelier.name).join(', '),
                ].join(' · '),
                style: const TextStyle(fontSize: 13),
              ),
              if ((data[d.id]?.ongoing ?? const []).isNotEmpty)
                Text('En cours : ${data[d.id]!.ongoing.map((i) => i.atelier.name).join(', ')}',
                    style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrls[d.id],
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => _scheduleSave(app, child),
                decoration: InputDecoration(
                  labelText: 'Commentaire de l\'enseignant(e)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: DictationButton(
                      controller: _ctrls[d.id]!, onChanged: (_) => _scheduleSave(app, child)),
                ),
              ),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _syntheseBody(AppStateProvider app, Child child) {
    final entry = app.carnetFor(child.id, CarnetEntry.synthese);
    final suggestions = {
      for (final s in EduscolData.subdomains) s.id: CarnetService.suggestedLevel(app, child, s.id),
    };
    void setLevel(String subId, String? level) {
      final levels = Map<String, String>.from(app.carnetFor(child.id, CarnetEntry.synthese).levels);
      level == null ? levels.remove(subId) : levels[subId] = level;
      app.saveCarnet(app.carnetFor(child.id, CarnetEntry.synthese).copyWith(levels: levels));
    }

    final missing = [
      for (final s in EduscolData.subdomains)
        if (entry.levels[s.id] == null && suggestions[s.id] != null) s.id,
    ];
    return [
      const Text(
        'Pour chaque sous-domaine du programme, choisissez le niveau. L\'appli suggère un niveau d\'après '
        'les observations de l\'année (au moins la moitié des ateliers réussis : « réussit souvent »).',
        style: TextStyle(fontSize: 12, color: kMutedTextColor),
      ),
      if (missing.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text('Appliquer les ${missing.length} suggestion(s)'),
            onPressed: () {
              final levels = Map<String, String>.from(entry.levels);
              for (final id in missing) {
                levels[id] = suggestions[id]!;
              }
              app.saveCarnet(entry.copyWith(levels: levels));
            },
          ),
        ),
      for (final d in EduscolData.domainsForCycle(1))
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: TextStyle(fontWeight: FontWeight.bold, color: hexToColor(d.colorHex))),
              for (final s in EduscolData.subdomainsOf(d.id)) ...[
                const SizedBox(height: 10),
                Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (suggestions[s.id] != null)
                  Text('Suggéré : ${CarnetEntry.levelLabels[suggestions[s.id]]}',
                      style: const TextStyle(fontSize: 11, color: kMutedTextColor)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final l in const [CarnetEntry.levelNotYet, CarnetEntry.levelOnTheWay, CarnetEntry.levelOften])
                    ChoiceChip(
                      label: Text(CarnetEntry.levelLabels[l]!, style: const TextStyle(fontSize: 12)),
                      selected: entry.levels[s.id] == l,
                      onSelected: (sel) => setLevel(s.id, sel ? l : null),
                    ),
                ]),
              ],
            ]),
          ),
        ),
      for (final (key, label) in const [('strengths', 'Points forts'), ('needs', 'Besoins à prendre en compte')])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _ctrls[key],
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => _scheduleSave(app, child),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: DictationButton(controller: _ctrls[key]!, onChanged: (_) => _scheduleSave(app, child)),
            ),
          ),
        ),
    ];
  }
}
