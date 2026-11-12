import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/child.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../services/parcours_progress.dart';
import '../services/parcours_start.dart';
import '../utils/color_utils.dart';
import '../widgets/child_multi_picker.dart';

/// Fait demarrer des eleves (la classe, une section, un groupe de besoin ou
/// une liste choisie) au milieu d'un parcours, et non forcement au debut.
///
/// Les etapes avant le depart ne leur sont plus demandees : pas de verrou, pas
/// de retard, et aucune observation n'est creee a leur place. On peut a tout
/// moment les remettre au debut du parcours.
class ParcoursStartScreen extends StatefulWidget {
  const ParcoursStartScreen({super.key, required this.progression});

  final Progression progression;

  @override
  State<ParcoursStartScreen> createState() => _ParcoursStartScreenState();
}

class _ParcoursStartScreenState extends State<ParcoursStartScreen> {
  final Set<String> _selected = {};

  /// Etape de depart choisie ; null : depuis le debut du parcours.
  String? _stepId;

  Widget _subtitle(AppStateProvider app, Child child) {
    final steps = app.ateliersInProgressionOrdered(widget.progression.id);
    final start = ParcoursStart.indexFor(child, widget.progression.id, steps);
    final position = ParcoursProgress.of(
      provider: app,
      parcours: widget.progression,
      steps: steps,
      childId: child.id,
    );
    final startText = start == 0
        ? 'Depuis le début'
        : 'Démarre à l\'étape ${start + 1} · ${steps[start].name}';
    final nowText = position.finished
        ? 'parcours terminé'
        : 'en ce moment : étape ${position.step + 1}';
    return Text('$startText · $nowText',
        style: const TextStyle(fontSize: 12, color: kMutedTextColor));
  }

  void _apply(AppStateProvider app) {
    final steps = app.ateliersInProgressionOrdered(widget.progression.id);
    // Partir de la premiere etape = partir du debut : rien a memoriser.
    final target = (_stepId == null || (steps.isNotEmpty && steps.first.id == _stepId)) ? null : _stepId;

    // Etat d'avant, pour pouvoir annuler d'un tap.
    final previous = {
      for (final id in _selected)
        if (app.childById(id) case final c?) id: c.parcoursStarts[widget.progression.id],
    };
    final changed = app.setParcoursStart(
      childIds: _selected,
      progressionId: widget.progression.id,
      atelierId: target,
    );

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final stepName = target == null ? null : app.activityTypeById(target)?.name;
    messenger.showSnackBar(SnackBar(
      content: Text(changed == 0
          ? 'Rien à changer : ces élèves étaient déjà à cette étape.'
          : target == null
              ? '$changed élève(s) remis au début de « ${widget.progression.name} ».'
              : '$changed élève(s) démarrent « ${widget.progression.name} » à « $stepName ».'),
      action: changed == 0
          ? null
          : SnackBarAction(
              label: 'Annuler',
              onPressed: () {
                for (final entry in previous.entries) {
                  app.setParcoursStart(
                    childIds: [entry.key],
                    progressionId: widget.progression.id,
                    atelierId: entry.value,
                  );
                }
              },
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final progression = app.progressionById(widget.progression.id) ?? widget.progression;
    final steps = app.ateliersInProgressionOrdered(progression.id);
    final children = ParcoursProgress.childrenFollowing(app, progression);
    final stepNumber = _stepId == null ? 0 : steps.indexWhere((s) => s.id == _stepId);
    final toBeginning = stepNumber <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Démarrer en cours de parcours')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(progression.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Les étapes avant le départ ne sont plus demandées à ces élèves : '
                      'elles ne les bloquent pas et ne comptent pas en retard.',
                      style: TextStyle(fontSize: 12, color: kMutedTextColor),
                    ),
                    const SizedBox(height: 16),
                    if (steps.isEmpty)
                      const Text("Ce parcours n'a pas encore d'étape.",
                          style: TextStyle(color: kMutedTextColor))
                    else ...[
                      DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: steps.any((s) => s.id == _stepId) ? _stepId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Étape de départ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Depuis le début (étape 1)')),
                          for (final (i, s) in steps.indexed)
                            if (i > 0)
                              DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text('Étape ${i + 1} · ${s.name}', overflow: TextOverflow.ellipsis),
                              ),
                        ],
                        onChanged: (v) => setState(() => _stepId = v),
                      ),
                      const Divider(height: 28),
                      Text('Élèves (${_selected.length} choisi(s))',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      if (children.isEmpty)
                        const Text('Aucun élève ne suit ce parcours (sections ciblées).',
                            style: TextStyle(color: kMutedTextColor))
                      else
                        ChildMultiPicker(
                          children: children,
                          selected: _selected,
                          onChanged: (next) => setState(() {
                            _selected
                              ..clear()
                              ..addAll(next);
                          }),
                          subtitleOf: (c) => _subtitle(app, c),
                        ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty || steps.isEmpty ? null : () => _apply(app),
                      icon: const Icon(Icons.fast_forward),
                      label: Text(_selected.isEmpty
                          ? 'Choisissez des élèves'
                          : toBeginning
                              ? 'Remettre ${_selected.length} élève(s) au début'
                              : 'Faire démarrer ${_selected.length} élève(s) à l\'étape ${stepNumber + 1}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: hexToColor(progression.colorHex),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
