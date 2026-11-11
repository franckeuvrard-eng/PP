import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../services/child_activity_report_service.dart';
import '../utils/color_utils.dart';

enum _Period { all, month, week, custom }

/// Reglages du rapport des eleves : periode, analyse des sons,
/// referentiels, regroupement des activites. Null si l'on annule.
Future<ChildReportOptions?> showChildReportOptionsDialog(
  BuildContext context, {
  required AppStateProvider provider,
}) {
  var period = _Period.all;
  DateTimeRange? custom;
  var onlyLatest = false;
  var includeSons = true;
  var group = true;
  final referentials = {for (final r in provider.referentials) r.id};

  return showDialog<ChildReportOptions>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setSt) {
        (DateTime?, DateTime?) range() {
          final now = DateTime.now();
          switch (period) {
            case _Period.all:
              return (null, null);
            case _Period.month:
              return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
            case _Period.week:
              final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
              return (monday, monday.add(const Duration(days: 7)));
            case _Period.custom:
              return custom == null
                  ? (null, null)
                  : (custom!.start, custom!.end.add(const Duration(days: 1)));
          }
        }

        Widget periodTile(_Period value, String label, IconData icon) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                period == value ? Icons.radio_button_checked : Icons.radio_button_off,
                color: period == value ? const Color(0xFF4E9F3D) : null,
              ),
              title: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Flexible(child: Text(label))]),
              onTap: () async {
                if (value == _Period.custom) {
                  final picked = await showDateRangePicker(
                    context: dialogContext,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: custom,
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked == null) return;
                  custom = picked;
                }
                setSt(() => period = value);
              },
            );

        return AlertDialog(
          title: const Text('Rapport des élèves'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Période', style: TextStyle(fontWeight: FontWeight.bold)),
                  periodTile(_Period.all, 'Toute la période', Icons.all_inclusive),
                  periodTile(_Period.month, 'Ce mois-ci', Icons.calendar_month),
                  periodTile(_Period.week, 'Semaine en cours', Icons.view_week),
                  periodTile(
                      _Period.custom,
                      custom == null
                          ? 'Période personnalisée…'
                          : '${DateFormat('dd/MM/yyyy').format(custom!.start)} → ${DateFormat('dd/MM/yyyy').format(custom!.end)}',
                      Icons.tune),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Regrouper les activités'),
                    subtitle: const Text('Par domaine et sous-domaine, et par parcours (sinon par date)'),
                    value: group,
                    onChanged: (v) => setSt(() => group = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Occurrence la plus récente seulement'),
                    subtitle: const Text('Sinon, chaque fois où un atelier a été refait apparaît'),
                    value: onlyLatest,
                    onChanged: (v) => setSt(() => onlyLatest = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Analyse des sons'),
                    subtitle: const Text('État actuel de chaque son, en tête du rapport'),
                    value: includeSons,
                    onChanged: (v) => setSt(() => includeSons = v),
                  ),
                  if (provider.referentials.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text('Référentiels à inclure', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in provider.referentials)
                          FilterChip(
                            label: Text(r.name),
                            selected: referentials.contains(r.id),
                            onSelected: (sel) => setSt(() => sel ? referentials.add(r.id) : referentials.remove(r.id)),
                          ),
                      ],
                    ),
                  ] else
                    const Text('Vos référentiels personnalisés apparaîtront ici.',
                        style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Générer'),
              onPressed: () {
                final (from, to) = range();
                Navigator.pop(
                  dialogContext,
                  ChildReportOptions(
                    from: from,
                    to: to,
                    onlyLatestPerAtelier: onlyLatest,
                    includeSons: includeSons,
                    groupActivities: group,
                    // Tous coches : pas de filtre (un referentiel cree plus tard reste inclus).
                    referentialIds:
                        referentials.length == provider.referentials.length ? null : Set.of(referentials),
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
