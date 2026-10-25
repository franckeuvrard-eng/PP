import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/evaluation_status.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/parcours_progress.dart';
import '../services/parcours_frise_pdf_service.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import 'atelier_detail_screen.dart';
import 'progressions_settings_tab.dart';
import '../services/qr_sheets_pdf_service.dart';

/// Écran « Parcours » : onglet Suivi (chaque parcours est un fil, ses étapes
/// en sont les jalons ; vue classe ou vue d'un élève) et onglet Gérer
/// (création des parcours et de leurs étapes).
class ProgressionsScreen extends StatefulWidget {
  const ProgressionsScreen({super.key, this.initialChildId});

  /// Ouvre directement la vue de cet élève.
  final String? initialChildId;

  @override
  State<ProgressionsScreen> createState() => _ProgressionsScreenState();
}

class _ProgressionsScreenState extends State<ProgressionsScreen> {
  String? _progressionId;

  /// Null : vue classe.
  String? _childId;

  @override
  void initState() {
    super.initState();
    _childId = widget.initialChildId;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final progressions = provider.progressions;
    final progression = progressions.isEmpty
        ? null
        : provider.progressionById(_progressionId) ?? progressions.first;

    // Deux onglets : le suivi (le fil) et la gestion des parcours, sortie
    // des Parametres pour que tout ce qui touche aux parcours soit ici.
    return DefaultTabController(
      length: 2,
      // Sans parcours, on arrive sur la gestion pour en creer un.
      initialIndex: progressions.isEmpty ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parcours'),
          actions: [
            if (progression != null) ...[
              IconButton(
                icon: const Icon(Icons.qr_code_2),
                tooltip: 'QR codes des étapes',
                onPressed: () => _exportQr(context, provider, progression),
              ),
              IconButton(
                icon: const Icon(Icons.view_carousel_outlined),
                tooltip: 'Imprimer la frise de ce parcours',
                onPressed: () => ParcoursFrisePdfService.export(
                    context: context, provider: provider, parcours: progression),
              ),
            ],
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.route), text: 'Suivi'),
              Tab(icon: Icon(Icons.edit_road), text: 'Gérer'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            progression == null
                ? Builder(
                    builder: (context) => _EmptyProgressions(
                        onCreate: () => DefaultTabController.of(context).animateTo(1)),
                  )
                : _buildTrack(provider, progressions, progression),
            const ProgressionsSettingsTab(),
          ],
        ),
      ),
    );
  }

  /// QR codes des etapes : ce parcours ou tous, une ou plusieurs pages par
  /// parcours.
  Future<void> _exportQr(BuildContext context, AppStateProvider provider, Progression current) async {
    final all = provider.progressions.length > 1
        ? await showDialog<bool>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('QR codes des étapes'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Parcours « ${current.name} »'),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Tous les parcours (${provider.progressions.length})'),
                ),
              ],
            ),
          )
        : false;
    if (all == null || !context.mounted) return;
    QrSheetsPdfService.openParcours(context, provider, all ? provider.progressions : [current]);
  }

  Widget _buildTrack(AppStateProvider provider, List<Progression> progressions, Progression progression) {
    final child = _childId == null ? null : provider.childById(_childId!);
    final children = provider.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (progressions.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in progressions)
                  ChoiceChip(
                    avatar: Icon(iconForName(p.iconName, fallback: Icons.timeline),
                        size: 18, color: hexToColor(p.colorHex)),
                    label: Text(p.name),
                    selected: p.id == progression.id,
                    onSelected: (_) => setState(() => _progressionId = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.groups), label: Text('La classe')),
                  ButtonSegment(value: true, icon: Icon(Icons.person), label: Text('Un élève')),
                ],
                selected: {child != null},
                onSelectionChanged: (sel) => setState(() {
                  _childId = sel.first
                      ? (children.isEmpty ? null : (child ?? children.first).id)
                      : null;
                }),
              ),
              if (child != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: child.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Élève',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in children)
                        DropdownMenuItem(value: c.id, child: Text(_fullName(c), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) => setState(() => _childId = id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressionCard(
            progression: progression,
            child: child,
            onChildTap: (c) => setState(() => _childId = c.id),
          ),
        ],
    );
  }
}

String _fullName(Child c) => '${c.firstname} ${c.lastname ?? ''}'.trim();

class _EmptyProgressions extends StatelessWidget {
  const _EmptyProgressions({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Aucun parcours',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Un parcours est une suite d'étapes à faire dans l'ordre, comme un "
              'chemin : couper une bande, puis une ligne droite, puis une courbe…',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMutedTextColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Créer un parcours'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une progression : en-tête et fil des jalons, pour la classe
/// ([child] nul) ou pour un élève.
class ProgressionCard extends StatelessWidget {
  const ProgressionCard({super.key, required this.progression, this.child, this.onChildTap});

  final Progression progression;
  final Child? child;

  /// Tap sur la pastille d'un élève (vue classe).
  final ValueChanged<Child>? onChildTap;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final color = hexToColor(progression.colorHex);
    final jalons = provider.ateliersInProgressionOrdered(progression.id);
    String? threshold;
    for (final s in provider.evaluationStatuses) {
      if (s.id == progression.minStatusId) threshold = s.label;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Icon(iconForName(progression.iconName, fallback: Icons.timeline),
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child == null ? progression.name : '${progression.name} · ${child!.firstname}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        [
                          '${jalons.length} étape(s)',
                          if (threshold != null) 'on passe au suivant à « $threshold »',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: kMutedTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (progression.description != null && progression.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(progression.description!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 16),
            if (jalons.isEmpty)
              const Text(
                "Aucune étape pour l'instant : ajoutez-en à ce parcours dans "
                "l'onglet Gérer.",
                style: TextStyle(color: kMutedTextColor),
              )
            else
              ProgressionTrack(
                progression: progression,
                jalons: jalons,
                child: child,
                onChildTap: onChildTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// Etat d'un jalon pour un eleve.
enum _JalonState { validated, current, locked }

/// Le fil : horizontal quand la place le permet (Mac, iPad), vertical sinon.
class ProgressionTrack extends StatelessWidget {
  const ProgressionTrack({
    super.key,
    required this.progression,
    required this.jalons,
    this.child,
    this.onChildTap,
    this.forceVertical = false,
  });

  final Progression progression;
  final List<ActivityType> jalons;
  final Child? child;
  final ValueChanged<Child>? onChildTap;
  final bool forceVertical;

  static const _nodeWidth = 156.0;
  static const _dot = 46.0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final data = _TrackData(provider, progression, jalons);

    return LayoutBuilder(builder: (context, constraints) {
      final horizontal = !forceVertical && constraints.maxWidth >= 640;
      final count = jalons.length + 1; // + arrivee
      if (horizontal) {
        final width = (constraints.maxWidth / count).clamp(_nodeWidth, 220.0);
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(width: width, child: _node(context, data, i, horizontal: true)),
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < count; i++) _node(context, data, i, horizontal: false),
        ],
      );
    });
  }

  Widget _node(BuildContext context, _TrackData data, int i, {required bool horizontal}) {
    final last = jalons.length;
    final isFinish = i == last;
    final color = hexToColor(progression.colorHex);
    final muted = Theme.of(context).dividerColor;

    // Segments du fil avant / apres ce jalon : colores une fois franchis.
    final Color before;
    final Color after;
    if (child == null) {
      before = i == 0 ? Colors.transparent : color.withValues(alpha: 0.5);
      after = isFinish ? Colors.transparent : color.withValues(alpha: 0.5);
    } else {
      final step = data.stepOf(child!.id);
      before = i == 0 ? Colors.transparent : (i <= step ? color : muted);
      after = isFinish ? Colors.transparent : (i < step ? color : muted);
    }

    final dot = isFinish ? _finishDot(context, data, color) : _jalonDot(context, data, i, color);
    final content = isFinish ? _finishContent(context, data) : _jalonContent(context, data, i);

    final onTap = isFinish
        ? null
        : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AtelierDetailScreen(atelier: jalons[i])),
            );

    if (horizontal) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: _dot + 16,
              child: Row(
                children: [
                  Expanded(child: Container(height: 4, color: before)),
                  dot,
                  Expanded(child: Container(height: 4, color: after)),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: content),
          ],
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _dot + 12,
              child: Column(
                children: [
                  Container(width: 4, height: 8, color: before),
                  dot,
                  Expanded(child: Container(width: 4, constraints: const BoxConstraints(minHeight: 16), color: after)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jalonDot(BuildContext context, _TrackData data, int i, Color color) {
    final atelier = jalons[i];
    if (child == null) {
      return _circle(color, Text('${i + 1}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)));
    }
    final state = data.stateOf(child!.id, i);
    final status = data.latestStatus(child!.id, atelier.id);
    switch (state) {
      case _JalonState.validated:
        return _circle(status == null ? color : hexToColor(status.colorHex),
            const Icon(Icons.check, color: Colors.white, size: 26));
      case _JalonState.current:
        return Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status == null ? Theme.of(context).cardColor : hexToColor(status.colorHex),
            border: Border.all(color: color, width: 4),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)],
          ),
          alignment: Alignment.center,
          child: Text('${i + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: status == null ? color : Colors.white)),
        );
      case _JalonState.locked:
        return _circle(Theme.of(context).disabledColor.withValues(alpha: 0.25),
            Icon(Icons.lock, color: Theme.of(context).disabledColor, size: 20));
    }
  }

  Widget _finishDot(BuildContext context, _TrackData data, Color color) {
    final done = child != null && data.stepOf(child!.id) >= jalons.length;
    return _circle(done || child == null ? color : Theme.of(context).disabledColor.withValues(alpha: 0.25),
        Icon(Icons.flag, color: done || child == null ? Colors.white : Theme.of(context).disabledColor));
  }

  Widget _circle(Color fill, Widget inside) => Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        alignment: Alignment.center,
        child: inside,
      );

  Widget _jalonContent(BuildContext context, _TrackData data, int i) {
    final atelier = jalons[i];
    final name = Text(atelier.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

    if (child == null) {
      final total = data.children.length;
      final validated = data.validatedCount(atelier.id);
      final here = data.childrenAtStep(i);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          name,
          const SizedBox(height: 4),
          Text('✓ $validated / $total', style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : validated / total,
              minHeight: 6,
              color: hexToColor(progression.colorHex),
              backgroundColor: hexToColor(progression.colorHex).withValues(alpha: 0.15),
            ),
          ),
          if (here.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${here.length} élève(s) ici', style: const TextStyle(fontSize: 11, color: kMutedTextColor)),
            const SizedBox(height: 4),
            _faces(here),
          ],
        ],
      );
    }

    final state = data.stateOf(child!.id, i);
    final log = data.latestLog(child!.id, atelier.id);
    final status = data.latestStatus(child!.id, atelier.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        name,
        const SizedBox(height: 4),
        if (state == _JalonState.current)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: hexToColor(progression.colorHex),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${child!.firstname} est ici',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        if (state == _JalonState.locked)
          const Text('Verrouillé', style: TextStyle(fontSize: 12, color: kMutedTextColor)),
        if (log != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${status?.label ?? 'Observé'} · ${DateFormat('dd/MM/yyyy').format(log.timestamp)}',
              style: const TextStyle(fontSize: 12, color: kMutedTextColor),
            ),
          ),
      ],
    );
  }

  Widget _finishContent(BuildContext context, _TrackData data) {
    if (child == null) {
      final done = data.childrenAtStep(jalons.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Arrivée', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${done.length} élève(s) ont terminé',
              style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
          if (done.isNotEmpty) ...[const SizedBox(height: 4), _faces(done)],
        ],
      );
    }
    final finished = data.stepOf(child!.id) >= jalons.length;
    return Text(finished ? 'Parcours terminé !' : 'Arrivée',
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: finished ? hexToColor(progression.colorHex) : null));
  }

  Widget _faces(List<Child> kids) {
    const max = 8;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final c in kids.take(max))
          Tooltip(
            message: _fullName(c),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onChildTap == null ? null : () => onChildTap!(c),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: hexToColor(c.colorHex),
                child: Text(c.avatarText,
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        if (kids.length > max)
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey,
            child: Text('+${kids.length - max}',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

/// Calculs du fil, faits une fois par affichage.
class _TrackData {
  _TrackData(this.provider, this.progression, this.jalons)
      // Vue classe : seuls les eleves des sections qui suivent le parcours.
      : children = ParcoursProgress.childrenFollowing(provider, progression);

  final AppStateProvider provider;
  final Progression progression;
  final List<ActivityType> jalons;
  final List<Child> children;
  final _steps = <String, int>{};
  final _validated = <String, bool>{};

  bool validated(String childId, String atelierId) => _validated.putIfAbsent(
      '$childId\u0000$atelierId',
      () => AtelierEligibilityService.meetsThreshold(provider, childId, atelierId, progression.minStatusId));

  /// Rang du premier jalon pas encore valide (= jalons.length : termine).
  int stepOf(String childId) => _steps.putIfAbsent(childId, () {
        for (var i = 0; i < jalons.length; i++) {
          if (!validated(childId, jalons[i].id)) return i;
        }
        return jalons.length;
      });

  _JalonState stateOf(String childId, int i) {
    final step = stepOf(childId);
    if (i < step) return _JalonState.validated;
    if (i == step) return _JalonState.current;
    return _JalonState.locked;
  }

  List<Child> childrenAtStep(int i) => [for (final c in children) if (stepOf(c.id) == i) c];

  int validatedCount(String atelierId) => children.where((c) => validated(c.id, atelierId)).length;

  ActivityLog? latestLog(String childId, String atelierId) {
    final logs = provider.activitiesForChild(childId).where((l) => l.activityTypeId == atelierId);
    if (logs.isEmpty) return null;
    return logs.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
  }

  EvaluationStatus? latestStatus(String childId, String atelierId) {
    final log = latestLog(childId, atelierId);
    if (log == null || log.evaluationStatusId == null) return null;
    for (final s in provider.evaluationStatuses) {
      if (s.id == log.evaluationStatusId) return s;
    }
    return null;
  }
}
