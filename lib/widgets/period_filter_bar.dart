import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Raccourcis de periode proposes sur les ecrans de suivi par atelier.
enum QuickPeriod { toutes, semaine, mois, personnalise }

/// Plage de dates correspondant a un raccourci, ou null pour "Toutes dates".
///
/// Pour [QuickPeriod.personnalise], la plage vient du date range picker
/// (voir [pickCustomPeriodRange]) : cette fonction renvoie alors null pour
/// laisser l'appelant conserver la selection en cours.
DateTimeRange? quickPeriodRange(QuickPeriod period) {
  final now = DateTime.now();
  switch (period) {
    case QuickPeriod.toutes:
      return null;
    case QuickPeriod.semaine:
      return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    case QuickPeriod.mois:
      return DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now);
    case QuickPeriod.personnalise:
      return null;
  }
}

/// Ouvre le selecteur de plage de dates et renvoie la selection, ou null si
/// l'utilisateur annule.
Future<DateTimeRange?> pickCustomPeriodRange(BuildContext context, DateTimeRange? current) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 3),
    lastDate: now,
    initialDateRange: current,
  );
}

/// Rangee de puces (Toutes dates / Cette semaine / Ce mois-ci / Personnalise)
/// commune aux ecrans de suivi par atelier (individuel et classe entiere).
class PeriodFilterBar extends StatelessWidget {
  final QuickPeriod quick;
  final DateTimeRange? period;
  final ValueChanged<QuickPeriod> onQuickSelected;
  final VoidCallback onPickCustomRange;

  const PeriodFilterBar({
    super.key,
    required this.quick,
    required this.period,
    required this.onQuickSelected,
    required this.onPickCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Toutes dates'),
            selected: quick == QuickPeriod.toutes,
            onSelected: (_) => onQuickSelected(QuickPeriod.toutes),
          ),
          ChoiceChip(
            label: const Text('Cette semaine'),
            selected: quick == QuickPeriod.semaine,
            onSelected: (_) => onQuickSelected(QuickPeriod.semaine),
          ),
          ChoiceChip(
            label: const Text('Ce mois-ci'),
            selected: quick == QuickPeriod.mois,
            onSelected: (_) => onQuickSelected(QuickPeriod.mois),
          ),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              quick == QuickPeriod.personnalise && period != null
                  ? '${dateFormat.format(period!.start)} → ${dateFormat.format(period!.end)}'
                  : 'Personnalisé…',
            ),
            onPressed: onPickCustomRange,
          ),
        ],
      ),
    );
  }
}
