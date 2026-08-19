import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/atelier_status_resolver.dart';
import 'atelier_history_screen.dart';

enum _QuickPeriod { toutes, semaine, mois, personnalise }

const String _kAllSections = '__toutes__';

/// Vue classe entiere : un tableau eleves x ateliers, meme regle
/// d'eligibilite par section que le suivi individuel. Complement de la
/// "Progression Detaillee par Eleve" de l'ecran Statistiques (qui compte les
/// evaluations toutes ateliers confondues), ici on descend jusqu'a l'atelier.
class AteliersClassProgressScreen extends StatefulWidget {
  const AteliersClassProgressScreen({super.key});

  @override
  State<AteliersClassProgressScreen> createState() => _AteliersClassProgressScreenState();
}

class _AteliersClassProgressScreenState extends State<AteliersClassProgressScreen> {
  DateTimeRange? _period;
  _QuickPeriod _quick = _QuickPeriod.toutes;
  String _section = _kAllSections;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _sectionInitialized = false;

  void _setQuick(_QuickPeriod period) {
    final now = DateTime.now();
    setState(() {
      _quick = period;
      switch (period) {
        case _QuickPeriod.toutes:
          _period = null;
          break;
        case _QuickPeriod.semaine:
          _period = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
          break;
        case _QuickPeriod.mois:
          _period = DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now);
          break;
        case _QuickPeriod.personnalise:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _period,
    );
    if (picked == null) return;
    setState(() {
      _quick = _QuickPeriod.personnalise;
      _period = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // Par defaut, la premiere section connue : un tableau croisant tous les
    // eleves de la classe avec tous les ateliers de toutes les sections est
    // illisible des la deuxieme section. Fait une seule fois, pas a chaque
    // build, pour laisser l'enseignant choisir "Toutes" ensuite.
    if (!_sectionInitialized) {
      _sectionInitialized = true;
      if (provider.sections.isNotEmpty) _section = provider.sections.first;
    }

    final children = _section == _kAllSections
        ? provider.children
        : provider.children.where((c) => c.group == _section).toList();

    // Meme regle de ciblage par section que le scan/la saisie manuelle
    // (AtelierEligibilityService), mais sans le verrou de progression : ici
    // on choisit seulement les colonnes du tableau, le verrou se juge par
    // eleve dans chaque cellule.
    final ateliers = provider.activityTypes.where((a) {
      if (_section == _kAllSections) return true;
      return !a.isObligatory || a.isObligatoryForGroup(_section);
    }).toList()
      ..sort((a, b) {
        final spaceCompare = (provider.spaceById(a.spaceId)?.name ?? '').compareTo(provider.spaceById(b.spaceId)?.name ?? '');
        return spaceCompare != 0 ? spaceCompare : a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Ateliers · toute la classe')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Toutes dates'),
                  selected: _quick == _QuickPeriod.toutes,
                  onSelected: (_) => _setQuick(_QuickPeriod.toutes),
                ),
                ChoiceChip(
                  label: const Text('Cette semaine'),
                  selected: _quick == _QuickPeriod.semaine,
                  onSelected: (_) => _setQuick(_QuickPeriod.semaine),
                ),
                ChoiceChip(
                  label: const Text('Ce mois-ci'),
                  selected: _quick == _QuickPeriod.mois,
                  onSelected: (_) => _setQuick(_QuickPeriod.mois),
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _quick == _QuickPeriod.personnalise && _period != null
                        ? '${_dateFormat.format(_period!.start)} → ${_dateFormat.format(_period!.end)}'
                        : 'Personnalisé…',
                  ),
                  onPressed: _pickCustomRange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.groups, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _section,
                  items: [
                    const DropdownMenuItem(value: _kAllSections, child: Text('Toutes les sections')),
                    for (final s in provider.sections) DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (val) => setState(() => _section = val ?? _kAllSections),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: children.isEmpty || ateliers.isEmpty
                ? const Center(child: Text('Aucun élève ou aucun atelier pour cette sélection.'))
                : _buildTable(provider, children, ateliers),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(AppStateProvider provider, List<Child> children, List<ActivityType> ateliers) {
    const nameWidth = 130.0;
    const cellWidth = 84.0;
    const rowHeight = 40.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: Theme.of(context).dividerColor, width: 0.5),
          columnWidths: {
            0: const FixedColumnWidth(nameWidth),
            for (var i = 0; i < ateliers.length; i++) i + 1: const FixedColumnWidth(cellWidth),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant),
              children: [
                const SizedBox(height: rowHeight),
                for (final atelier in ateliers)
                  Tooltip(
                    message: atelier.name,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text(
                        atelier.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            for (final child in children)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Text(
                      '${child.firstname} ${child.lastname ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final atelier in ateliers) _buildCell(provider, child, atelier),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(AppStateProvider provider, Child child, ActivityType atelier) {
    final eligibility = AtelierEligibilityService.evaluate(provider: provider, child: child, atelier: atelier);
    if (eligibility.status == AtelierEligibility.blockedSection) {
      return const Center(child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)));
    }
    if (eligibility.status == AtelierEligibility.blockedProgression) {
      return Center(
        child: Tooltip(
          message: eligibility.message,
          child: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ),
      );
    }

    final snapshot = AtelierStatusResolver.resolve(
      provider: provider,
      childId: child.id,
      activityTypeId: atelier.id,
      period: _period,
    );
    final color = Color(int.parse(snapshot.colorHex.replaceFirst('#', '0xff')));

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AtelierHistoryScreen(child: child, atelier: atelier)),
      ),
      child: Center(
        child: Tooltip(
          message: '${child.firstname} · ${atelier.name} : ${snapshot.label}',
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: snapshot.hasLogInPeriod ? color : color.withOpacity(0.25),
              shape: BoxShape.circle,
              border: snapshot.hasLogInPeriod ? null : Border.all(color: color, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
