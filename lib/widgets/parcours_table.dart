import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/evaluation_status.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/parcours_progress.dart';
import '../services/parcours_start.dart';
import '../utils/color_utils.dart';

/// Etat d'une case du tableau.
enum ParcoursCell { validated, open, locked, skipped }

/// Tableau d'un parcours : les eleves en lignes, les etapes en colonnes, une
/// case a cocher par etape, pour valider vite et en masse.
///
/// Cocher enregistre une observation au niveau de passage du parcours ; decocher
/// ajoute une observation « premier niveau » (l'historique est conserve, rien
/// n'est supprime). Chaque geste propose « Annuler ». Le verrou du parcours est
/// respecte : une etape se coche dans l'ordre, sauf avec « Valider jusqu'a
/// l'etape… » qui enchaine toutes les etapes d'un eleve.
class ParcoursTable extends StatefulWidget {
  const ParcoursTable({super.key, required this.progression, this.onOpenChild, this.onOpenStep});

  final Progression progression;

  /// Ouvre la vue d'un eleve (nom dans la premiere colonne).
  final ValueChanged<Child>? onOpenChild;

  /// Ouvre la fiche d'une etape (en-tete de colonne).
  final ValueChanged<ActivityType>? onOpenStep;

  /// Niveau enregistre quand on coche : le seuil de passage du parcours.
  static String? thresholdId(AppStateProvider app, Progression parcours) {
    final statuses = app.evaluationStatuses;
    if (statuses.isEmpty) return null;
    return parcours.minStatusId ?? statuses.last.id;
  }

  /// Etat de chaque etape pour un eleve, dans l'ordre de [steps].
  static List<ParcoursCell> statesFor(
      AppStateProvider app, Progression parcours, List<ActivityType> steps, Child child) {
    final start = ParcoursStart.indexFor(child, parcours.id, steps);
    final validated = [
      for (var i = 0; i < steps.length; i++)
        i >= start && AtelierEligibilityService.meetsThreshold(app, child.id, steps[i].id, parcours.minStatusId),
    ];
    // La premiere etape pas encore validee (depuis le depart) est ouverte ;
    // les suivantes sont verrouillees tant qu'elle ne l'est pas.
    var current = steps.length;
    for (var i = start; i < steps.length; i++) {
      if (!validated[i]) {
        current = i;
        break;
      }
    }
    return [
      for (var i = 0; i < steps.length; i++)
        if (i < start)
          ParcoursCell.skipped
        else if (validated[i])
          ParcoursCell.validated
        else if (i == current)
          ParcoursCell.open
        else
          ParcoursCell.locked,
    ];
  }

  @override
  State<ParcoursTable> createState() => _ParcoursTableState();
}

class _ParcoursTableState extends State<ParcoursTable> {
  static const double _nameWidth = 150;
  static const double _colWidth = 78;
  static const double _rowHeight = 46;
  static const double _headHeight = 104;

  /// Observations creees par ce tableau depuis son ouverture : les decocher
  /// les supprime (annulation propre) au lieu d'ajouter un niveau bas.
  final Set<String> _mine = {};

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final steps = app.ateliersInProgressionOrdered(widget.progression.id);
    final children = ParcoursProgress.childrenFollowing(app, widget.progression);
    final color = hexToColor(widget.progression.colorHex);

    if (app.evaluationStatuses.isEmpty) {
      return const Text('Aucun niveau d\'évaluation : configurez-les dans les Paramètres.',
          style: TextStyle(color: kMutedTextColor));
    }
    if (steps.isEmpty) {
      return const Text("Ce parcours n'a pas encore d'étape.", style: TextStyle(color: kMutedTextColor));
    }
    if (children.isEmpty) {
      return const Text('Aucun élève ne suit ce parcours (sections ciblées).',
          style: TextStyle(color: kMutedTextColor));
    }

    final states = {for (final c in children) c.id: ParcoursTable.statesFor(app, widget.progression, steps, c)};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Touchez une case pour valider (ou retirer) une étape. Touchez le nom d\'une étape pour valider toute la '
          'colonne, ou celui d\'un élève pour valider ses étapes jusqu\'à l\'une d\'elles.',
          style: TextStyle(fontSize: 12, color: kMutedTextColor),
        ),
        const SizedBox(height: 8),
        _legend(context, color),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne des noms, fixe.
            SizedBox(
              width: _nameWidth,
              child: Column(
                children: [
                  const SizedBox(
                      height: _headHeight,
                      child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 6, left: 4),
                            child: Text('Élèves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ))),
                  for (final c in children) _nameCell(context, app, c, steps, states[c.id]!),
                ],
              ),
            ),
            // Les etapes defilent a l'horizontale.
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      Row(children: [
                        for (var i = 0; i < steps.length; i++)
                          _head(context, app, steps, i, children, states, color),
                      ]),
                      for (final c in children)
                        Row(children: [
                          for (var i = 0; i < steps.length; i++)
                            _cell(context, app, c, steps, i, states[c.id]![i], color),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Place sous la derniere ligne : la banniere (affichee en bas) ne
        // masque jamais un eleve, il suffit de remonter un peu la page.
        const SizedBox(height: 96),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color) {
    Widget item(Widget icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: kMutedTextColor)),
        ]);
    final muted = Theme.of(context).disabledColor;
    return Wrap(spacing: 14, runSpacing: 4, children: [
      item(_box(color, true, size: 16), 'Validée'),
      item(_box(color, false, size: 16, dot: Colors.orange), 'Observée, pas encore validée'),
      item(_box(color, false, size: 16), 'À faire'),
      item(Icon(Icons.lock_outline, size: 16, color: muted), 'Verrouillée'),
      item(Text('—', style: TextStyle(color: muted)), 'Non demandée (démarre plus loin)'),
    ]);
  }

  /// Case dessinee : pleine et cochee, ou vide (avec un point si observee).
  static Widget _box(Color color, bool checked, {double size = 28, Color? dot}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? color : null,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: checked ? color : (dot ?? Colors.grey.shade500), width: 2),
        ),
        alignment: Alignment.center,
        child: checked
            ? Icon(Icons.check, size: size * 0.7, color: Colors.white)
            : (dot == null
                ? null
                : Container(width: size * 0.3, height: size * 0.3, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
      );

  // ───────────────────────── en-tete d'une etape ─────────────────────────

  Widget _head(BuildContext context, AppStateProvider app, List<ActivityType> steps, int i,
      List<Child> children, Map<String, List<ParcoursCell>> states, Color color) {
    final step = steps[i];
    final eligible = [for (final c in children) if (states[c.id]![i] == ParcoursCell.open) c];
    final done = [for (final c in children) if (states[c.id]![i] == ParcoursCell.validated) c].length;
    final concerned = [for (final c in children) if (states[c.id]![i] != ParcoursCell.skipped) c].length;

    return SizedBox(
      width: _colWidth,
      height: _headHeight,
      child: PopupMenuButton<String>(
        key: Key('col_${step.id}'),
        tooltip: step.name,
        onSelected: (v) {
          if (v == 'all') {
            _validate(context, app, [for (final c in eligible) c.id], step,
                '« ${step.name} » : ${eligible.length} élève(s) validé(s).');
          } else if (v == 'open') {
            widget.onOpenStep?.call(step);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'all',
            enabled: eligible.isNotEmpty,
            child: Text(eligible.isEmpty
                ? 'Personne à valider (déjà fait, verrouillé ou non demandé)'
                : 'Valider pour ${eligible.length} élève(s) éligible(s)'),
          ),
          if (widget.onOpenStep != null) const PopupMenuItem(value: 'open', child: Text('Ouvrir la fiche de l\'étape')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(step.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$done/$concerned', style: const TextStyle(fontSize: 10, color: kMutedTextColor)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── nom d'un eleve ─────────────────────────

  Widget _nameCell(BuildContext context, AppStateProvider app, Child child, List<ActivityType> steps,
      List<ParcoursCell> states) {
    final full = '${child.firstname} ${child.lastname ?? ''}'.trim();
    final remaining = [
      for (var i = 0; i < steps.length; i++)
        if (states[i] == ParcoursCell.open || states[i] == ParcoursCell.locked) i,
    ];
    return SizedBox(
      height: _rowHeight,
      child: PopupMenuButton<int>(
        key: Key('row_${child.id}'),
        tooltip: full,
        enabled: remaining.isNotEmpty || widget.onOpenChild != null,
        onSelected: (v) {
          if (v < 0) {
            widget.onOpenChild?.call(child);
            return;
          }
          _validateUpTo(context, app, child, steps, states, v);
        },
        itemBuilder: (_) => [
          if (remaining.isEmpty)
            const PopupMenuItem<int>(enabled: false, value: -2, child: Text('Toutes les étapes sont validées')),
          for (final i in remaining)
            PopupMenuItem<int>(
              value: i,
              child: Text('Valider jusqu\'à l\'étape ${i + 1} · ${steps[i].name}',
                  overflow: TextOverflow.ellipsis),
            ),
          if (widget.onOpenChild != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<int>(value: -1, child: Text('Voir son parcours')),
          ],
        ],
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: hexToColor(child.colorHex),
              child: Text(child.avatarText,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(full,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── une case ─────────────────────────

  Widget _cell(BuildContext context, AppStateProvider app, Child child, List<ActivityType> steps, int i,
      ParcoursCell state, Color color) {
    final step = steps[i];
    final latest = _latestStatus(app, child.id, step.id);
    final statusColor = latest == null ? null : hexToColor(latest.colorHex);

    final Widget content;
    switch (state) {
      case ParcoursCell.validated:
        content = _box(statusColor ?? color, true);
      case ParcoursCell.open:
        content = _box(color, false, dot: statusColor);
      case ParcoursCell.locked:
        content = Icon(Icons.lock_outline, size: 20, color: Theme.of(context).disabledColor);
      case ParcoursCell.skipped:
        content = Text('—', style: TextStyle(color: Theme.of(context).disabledColor));
    }

    return InkWell(
      key: Key('cell_${child.id}_${step.id}'),
      onTap: () => _tap(context, app, child, steps, i, state),
      child: Tooltip(
        message: '${child.firstname} · étape ${i + 1} : ${step.name}'
            '${latest == null ? '' : ' · ${latest.label}'}',
        child: SizedBox(width: _colWidth, height: _rowHeight, child: Center(child: content)),
      ),
    );
  }

  static EvaluationStatus? _latestStatus(AppStateProvider app, String childId, String stepId) {
    ActivityLog? latest;
    for (final l in app.activitiesForChild(childId)) {
      if (l.activityTypeId != stepId) continue;
      if (latest == null || l.timestamp.isAfter(latest.timestamp)) latest = l;
    }
    return latest == null ? null : app.statusById(latest.evaluationStatusId);
  }

  // ───────────────────────── gestes ─────────────────────────

  void _tap(BuildContext context, AppStateProvider app, Child child, List<ActivityType> steps, int i,
      ParcoursCell state) {
    final step = steps[i];
    switch (state) {
      case ParcoursCell.open:
        // Pas de banniere : la case change tout de suite, et la retoucher
        // annule proprement. Une banniere par case gene quand on en valide
        // beaucoup (et masque la derniere ligne).
        _validate(context, app, [child.id], step, '', announce: false);
      case ParcoursCell.validated:
        _unvalidate(context, app, child, step);
      case ParcoursCell.locked:
        final states = ParcoursTable.statesFor(app, widget.progression, steps, child);
        final blocking = states.indexOf(ParcoursCell.open);
        _say(context,
            'Verrouillée : validez d\'abord ${blocking >= 0 ? 'l\'étape ${blocking + 1} · ${steps[blocking].name}' : 'l\'étape précédente'}.');
      case ParcoursCell.skipped:
        _say(context, 'Non demandée : ${child.firstname} démarre ce parcours plus loin.');
    }
  }

  /// Valide [step] pour ces eleves. Avec [announce], une banniere « Annuler »
  /// courte confirme le geste (actions en masse).
  void _validate(BuildContext context, AppStateProvider app, List<String> childIds, ActivityType step,
      String message,
      {bool announce = true}) {
    final threshold = ParcoursTable.thresholdId(app, widget.progression);
    if (childIds.isEmpty || threshold == null) return;
    final created = app.logActivityForChildren(
        childIds: childIds, activityTypeId: step.id, evaluationStatusId: threshold);
    _mine.addAll(created.map((l) => l.id));
    if (announce) _undoable(context, app, message, created);
  }

  /// Valide toutes les etapes de [child] jusqu'a l'etape de rang [upTo] (comprise).
  void _validateUpTo(BuildContext context, AppStateProvider app, Child child, List<ActivityType> steps,
      List<ParcoursCell> states, int upTo) {
    final threshold = ParcoursTable.thresholdId(app, widget.progression);
    if (threshold == null) return;
    final stamp = DateTime.now();
    final created = <ActivityLog>[];
    for (var i = 0; i <= upTo && i < steps.length; i++) {
      if (states[i] == ParcoursCell.validated || states[i] == ParcoursCell.skipped) continue;
      created.addAll(app.logActivityForChildren(
          childIds: [child.id],
          activityTypeId: steps[i].id,
          evaluationStatusId: threshold,
          timestamp: stamp));
    }
    _mine.addAll(created.map((l) => l.id));
    _undoable(context, app,
        '${child.firstname} : ${created.length} étape(s) validée(s) jusqu\'à « ${steps[upTo].name} ».', created);
  }

  /// Retire la validation : on ajoute une observation au premier niveau, ce
  /// qui conserve l'historique (notes, photos). Avec un seul niveau, la
  /// derniere observation est supprimee (et restituee par « Annuler »).
  void _unvalidate(BuildContext context, AppStateProvider app, Child child, ActivityType step) {
    // Validee ici a l'instant : on retire simplement cette observation, sans
    // laisser de trace (cocher puis decocher par erreur ne pollue pas l'historique).
    ActivityLog? newest;
    for (final l in app.activitiesForChild(child.id)) {
      if (l.activityTypeId != step.id) continue;
      if (newest == null || l.timestamp.isAfter(newest.timestamp)) newest = l;
    }
    if (newest != null && _mine.remove(newest.id)) {
      app.deleteActivityLog(newest.id);
      return;
    }

    final statuses = app.evaluationStatuses;
    if (statuses.length >= 2) {
      final created = app.logActivityForChildren(
          childIds: [child.id], activityTypeId: step.id, evaluationStatusId: statuses.first.id);
      _undoable(context, app,
          '${child.firstname} : « ${step.name} » retirée (${statuses.first.label}).', created);
      return;
    }
    ActivityLog? latest;
    for (final l in app.activitiesForChild(child.id)) {
      if (l.activityTypeId != step.id) continue;
      if (latest == null || l.timestamp.isAfter(latest.timestamp)) latest = l;
    }
    if (latest == null) return;
    final removed = app.deleteActivityLog(latest.id);
    if (removed == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('${child.firstname} : « ${step.name} » retirée.'),
        // Avec une action, Flutter garde le bandeau indefiniment : on force la
        // disparition apres quelques secondes.
        duration: const Duration(seconds: 3),
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Annuler', onPressed: () => app.restoreActivityLog(removed)),
      ));
  }

  void _undoable(BuildContext context, AppStateProvider app, String message, List<ActivityLog> created) {
    if (created.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        // Avec une action, Flutter garde le bandeau indefiniment : on force la
        // disparition apres quelques secondes.
        duration: const Duration(seconds: 3),
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            for (final log in created) {
              app.deleteActivityLog(log.id);
            }
          },
        ),
      ));
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }
}
