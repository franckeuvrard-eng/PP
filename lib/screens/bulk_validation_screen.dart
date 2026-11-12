import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/evaluation_status.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/atelier_status_resolver.dart';
import '../services/parcours_start.dart';
import '../utils/color_utils.dart';
import '../widgets/child_multi_picker.dart';

/// Mode « Plusieurs eleves » du Scan & Go : on choisit l'atelier (ou l'etape
/// de parcours), puis on valide pour plusieurs eleves d'un coup : meme niveau,
/// meme date, meme note, une observation par eleve.
///
/// Les eleves pour qui l'etape est verrouillee restent visibles mais grises :
/// la regle du parcours est la meme qu'a la saisie individuelle. Pour faire
/// commencer des eleves plus loin dans un parcours, voir
/// [ParcoursStartScreen].
class BulkValidationScreen extends StatefulWidget {
  /// [atelier] : atelier deja choisi ; sinon l'ecran commence par le choix.
  const BulkValidationScreen({super.key, this.atelier});

  final ActivityType? atelier;

  @override
  State<BulkValidationScreen> createState() => _BulkValidationScreenState();
}

class _BulkValidationScreenState extends State<BulkValidationScreen> {
  /// Atelier choisi (null : choix en cours).
  String? _atelierId;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _atelierId = widget.atelier?.id;
  }

  final Set<String> _selected = {};
  final TextEditingController _note = TextEditingController();
  String? _statusId;
  bool _statusChosen = false;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Niveau propose d'office : le seuil de passage du parcours, sinon le plus
  /// abouti (« Acquis »). L'enseignant le change d'un tap.
  String? _defaultStatus(AppStateProvider app) {
    final statuses = app.evaluationStatuses;
    if (statuses.isEmpty) return null;
    final parcours = app.progressionById(app.activityTypeById(_atelierId)?.progressionId);
    final wanted = parcours?.minStatusId;
    if (wanted != null && statuses.any((s) => s.id == wanted)) return wanted;
    return statuses.last.id;
  }

  DateTime get _timestamp {
    final now = DateTime.now();
    final sameDay = _date.year == now.year && _date.month == now.month && _date.day == now.day;
    // Un jour passe : midi, pour ne pas inventer une heure de la journee.
    return sameDay ? now : DateTime(_date.year, _date.month, _date.day, 12);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _disabledReason(AppStateProvider app, Child child, ActivityType atelier) {
    final result = AtelierEligibilityService.evaluate(provider: app, child: child, atelier: atelier);
    if (result.isAllowed) return null;
    return result.message.isEmpty ? 'Indisponible pour cet élève' : result.message;
  }

  Widget? _subtitle(AppStateProvider app, Child child, ActivityType atelier) {
    final snapshot = AtelierStatusResolver.resolve(
      provider: app,
      childId: child.id,
      activityTypeId: atelier.id,
    );
    final parts = <Widget>[
      Text(snapshot.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: hexToColor(snapshot.colorHex))),
    ];
    // Etape avant le depart de l'eleve : elle ne lui est pas demandee.
    final parcours = app.progressionById(atelier.progressionId);
    if (parcours != null) {
      final steps = app.ateliersInProgressionOrdered(parcours.id);
      final start = ParcoursStart.indexFor(child, parcours.id, steps);
      final index = steps.indexWhere((s) => s.id == atelier.id);
      if (index >= 0 && index < start) {
        parts.add(const Text(' · démarre plus loin',
            style: TextStyle(fontSize: 12, color: kMutedTextColor)));
      }
    }
    return Row(children: parts);
  }

  void _validate(AppStateProvider app, ActivityType atelier, EvaluationStatus? status) {
    final messenger = ScaffoldMessenger.of(context);
    final created = app.logActivityForChildren(
      childIds: _selected,
      activityTypeId: atelier.id,
      evaluationStatusId: status?.id,
      note: _note.text,
      timestamp: _timestamp,
    );
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('« ${atelier.name} » : ${created.length} élève(s) enregistré(s)'
          '${status == null ? '' : ' · ${status.label}'}.'),
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

  /// Premiere etape : choisir l'atelier ou l'etape de parcours.
  Widget _buildAtelierChoice(AppStateProvider app) {
    final q = _query.trim().toLowerCase();
    final all = app.activityTypes.where((a) => !a.isDisabled).toList()
      ..sort((a, b) {
        final byPlace = (app.placeOf(a)?.name ?? '').toLowerCase().compareTo((app.placeOf(b)?.name ?? '').toLowerCase());
        return byPlace != 0 ? byPlace : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final shown = [
      for (final a in all)
        if (q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            (app.placeOf(a)?.name ?? '').toLowerCase().contains(q) ||
            a.domaine.toLowerCase().contains(q))
          a,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Plusieurs élèves')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quel atelier ou quelle étape ?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Vous choisirez ensuite les élèves : la classe, une section, un groupe ou une liste.',
                        style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Rechercher un atelier, un espace, un parcours…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text('Aucun atelier trouvé.', style: TextStyle(color: kMutedTextColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final a = shown[i];
                          final place = app.placeOf(a);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hexToColor(a.colorHex),
                              child: Icon(a.inProgression ? Icons.flag : Icons.category,
                                  color: Colors.white, size: 20),
                            ),
                            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [
                                if (place != null) place.name,
                                if (a.inProgression) 'étape de parcours',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => setState(() {
                              _atelierId = a.id;
                              _statusChosen = false;
                              _selected.clear();
                            }),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    final chosen = app.activityTypeById(_atelierId);
    if (chosen == null) return _buildAtelierChoice(app);
    final atelier = chosen;
    final statuses = app.evaluationStatuses;
    if (!_statusChosen) {
      _statusId = _defaultStatus(app);
      _statusChosen = true;
    }
    final status = statuses.where((s) => s.id == _statusId).firstOrNull;
    final children = app.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    final place = app.placeOf(atelier);

    return Scaffold(
      appBar: AppBar(title: const Text('Plusieurs élèves')),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(atelier.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (place != null)
                                Text(place.name,
                                    style: TextStyle(
                                        color: hexToColor(atelier.colorHex), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            // Un autre atelier : les eleves coches (et leur
                            // eligibilite) ne valent plus.
                            _atelierId = null;
                            _selected.clear();
                          }),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Changer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Niveau atteint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final s in statuses)
                          ChoiceChip(
                            avatar: CircleAvatar(backgroundColor: hexToColor(s.colorHex), radius: 6),
                            label: Text(s.label),
                            selected: s.id == _statusId,
                            onSelected: (_) => setState(() => _statusId = s.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _note,
                            decoration: const InputDecoration(
                              labelText: 'Note (facultative)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text('Élèves (${_selected.length} choisi(s))',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (children.isEmpty)
                      const Text('Aucun élève dans la classe.', style: TextStyle(color: kMutedTextColor))
                    else
                      ChildMultiPicker(
                        children: children,
                        selected: _selected,
                        onChanged: (next) => setState(() {
                          _selected
                            ..clear()
                            ..addAll(next);
                        }),
                        disabledReasonOf: (c) => _disabledReason(app, c, atelier),
                        subtitleOf: (c) => _subtitle(app, c, atelier),
                      ),
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
                      onPressed: _selected.isEmpty ? null : () => _validate(app, atelier, status),
                      icon: const Icon(Icons.check),
                      label: Text(_selected.isEmpty
                          ? 'Choisissez des élèves'
                          : 'Enregistrer${status == null ? '' : ' « ${status.label} »'} pour ${_selected.length} élève(s)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4E9F3D),
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
