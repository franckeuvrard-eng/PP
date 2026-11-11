import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/eduscol_data.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../services/coverage_service.dart';
import '../utils/color_utils.dart';
import '../widgets/age_chip.dart';
import 'child_profile_screen.dart';

/// « A surveiller » : les domaines sans observation recente pour chaque
/// eleve, et les objectifs du programme qu'aucun atelier ne travaille.
class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  int _days = 21;
  final Set<String> _levels = {};

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('À surveiller'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.people), text: 'Élèves'),
            Tab(icon: Icon(Icons.school), text: 'Programme'),
          ]),
        ),
        body: TabBarView(children: [
          _children(provider),
          _programme(provider),
        ]),
      ),
    );
  }

  Widget _children(AppStateProvider provider) {
    final gaps = CoverageService.domainGaps(provider, days: _days);
    final byChild = <String, List<DomainGap>>{};
    for (final g in gaps) {
      (byChild[g.child.id] ??= []).add(g);
    }
    final children = provider.children.where((c) => byChild.containsKey(c.id)).toList()
      ..sort((a, b) => byChild[b.id]!.length.compareTo(byChild[a.id]!.length));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Domaines sans observation depuis :', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final d in const [14, 21, 30])
            ChoiceChip(
              label: Text('${d ~/ 7} semaines'),
              selected: _days == d,
              onSelected: (_) => setState(() => _days = d),
            ),
        ]),
        const SizedBox(height: 4),
        const Text('Seuls les domaines travaillés par au moins un atelier sont comptés.',
            style: TextStyle(fontSize: 12, color: kMutedTextColor)),
        const SizedBox(height: 12),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Rien à signaler : chaque élève a été observé dans chaque domaine.',
                textAlign: TextAlign.center, style: TextStyle(color: kMutedTextColor)),
          ),
        for (final c in children) _childCard(c, byChild[c.id]!),
      ],
    );
  }

  Widget _childCard(Child c, List<DomainGap> gaps) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChildProfileScreen(child: c))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: hexToColor(c.colorHex),
                  child: Text(c.avatarText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${c.firstname} ${c.lastname ?? ''}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (c.group != null && c.group!.isNotEmpty)
                  Text(c.group!, style: const TextStyle(color: kMutedTextColor)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in gaps)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(backgroundColor: hexToColor(g.domain.colorHex), radius: 6),
                      label: Text('${_short(g.domain.title)} · ${g.days == null ? 'jamais' : '${g.days} j'}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Intitules officiels raccourcis pour tenir dans une pastille.
  static String _short(String title) => const {
        'Le développement et la structuration du langage oral et écrit': 'Langage',
        "Agir, s'exprimer, comprendre à travers les activités physiques": 'Activités physiques',
        "Agir, s'exprimer, comprendre à travers les activités artistiques": 'Arts',
        "L'acquisition des premiers outils mathématiques": 'Maths',
        "Se repérer dans le temps et l'espace": 'Temps et espace',
        'Découvrir le monde du vivant, de la matière et des objets': 'Vivant, matière, objets',
      }[title] ??
      title;

  Widget _programme(AppStateProvider provider) {
    final missing = CoverageService.uncoveredObjectives(provider, levels: _levels);
    final (done, total) = CoverageService.objectiveCoverage(provider, levels: _levels);
    final bySub = <String, List<EduscolObjective>>{};
    for (final o in missing) {
      (bySub[o.subdomainId] ??= []).add(o);
    }
    final rows = <Widget>[];
    for (final d in EduscolData.domainsForCycle(1)) {
      final subs = EduscolData.subdomainsOf(d.id).where((s) => bySub.containsKey(s.id)).toList();
      if (subs.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(d.title, style: TextStyle(fontWeight: FontWeight.bold, color: hexToColor(d.colorHex))),
      ));
      for (final s in subs) {
        rows.add(Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('${bySub[s.id]!.length} objectif(s) sans atelier', style: const TextStyle(fontSize: 12)),
            children: [
              for (final o in bySub[s.id]!)
                ListTile(
                  dense: true,
                  title: Text(o.text, style: const TextStyle(fontSize: 13)),
                  subtitle: Align(alignment: Alignment.centerLeft, child: AgeChip(level: o.level)),
                ),
            ],
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in EduscolData.levels[1]!)
            FilterChip(
              label: Text('${EduscolData.ageLabel(l)} ($l)'),
              selected: _levels.contains(l),
              onSelected: (sel) => setState(() => sel ? _levels.add(l) : _levels.remove(l)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(_levels.isEmpty ? 'Tous les âges.' : 'Seulement les âges cochés.',
            style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
        const SizedBox(height: 14),
        Text('$done objectifs sur $total travaillés par au moins un atelier',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 12,
            color: const Color(0xFF4E9F3D),
            backgroundColor: const Color(0xFF4E9F3D).withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Pour en couvrir un, cochez-le dans les objectifs d\'un atelier ou d\'une étape.',
            style: TextStyle(fontSize: 12, color: kMutedTextColor)),
        if (missing.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tous les objectifs sont travaillés.', textAlign: TextAlign.center),
          ),
        ...rows,
      ],
    );
  }
}
