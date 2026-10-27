import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../services/mandatory_ateliers_pdf_service.dart';
import '../utils/color_utils.dart';

/// Reglages d'un plan de travail avant l'export : statut affiche ou non,
/// statuts a inclure, cases a cocher, et (rapport des parcours) parcours a
/// inclure. Renvoie null si l'on annule.
Future<WorkPlanOptions?> showWorkPlanOptionsDialog(
  BuildContext context, {
  required AppStateProvider provider,
  required bool forParcours,
}) {
  var showStatus = true;
  var showCheckboxes = true;
  var onlyPlanned = false;
  // Statuts : niveaux d'evaluation + « jamais fait ». Tous coches au depart.
  final statusOptions = <(String, String, String)>[
    (WorkPlanOptions.noLog, 'Jamais fait', '#9E9E9E'),
    for (final s in provider.evaluationStatuses) (s.id, s.label, s.colorHex),
  ];
  final statuses = {for (final s in statusOptions) s.$1};
  // Parcours : aucun coche = ceux que suit la section de chaque eleve.
  final parcours = <String>{};

  return showDialog<WorkPlanOptions>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setSt) => AlertDialog(
        title: Text(forParcours ? 'Rapport des parcours' : 'Plan de travail'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Format paysage, une page (ou plus) par élève.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Afficher le statut'),
                  subtitle: const Text('Sous le nom de chaque vignette'),
                  value: showStatus,
                  onChanged: (v) => setSt(() => showStatus = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Seulement ce qui est prévu cette semaine'),
                  subtitle: const Text('D’après le planning, pour chaque élève'),
                  value: onlyPlanned,
                  onChanged: (v) => setSt(() => onlyPlanned = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cases à cocher'),
                  subtitle: const Text('Trois cases sous chaque vignette, à cocher à la main'),
                  value: showCheckboxes,
                  onChanged: (v) => setSt(() => showCheckboxes = v),
                ),
                const SizedBox(height: 8),
                Text(forParcours ? 'Étapes à inclure, selon leur statut :' : 'Ateliers à inclure, selon leur statut :',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (id, label, hex) in statusOptions)
                      FilterChip(
                        avatar: CircleAvatar(backgroundColor: hexToColor(hex), radius: 6),
                        label: Text(label),
                        selected: statuses.contains(id),
                        onSelected: (sel) => setSt(() => sel ? statuses.add(id) : statuses.remove(id)),
                      ),
                  ],
                ),
                if (forParcours && provider.progressions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Parcours :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    parcours.isEmpty
                        ? 'Aucun coché : ceux que suit la section de chaque élève.'
                        : '${parcours.length} parcours choisi(s), pour tous les élèves.',
                    style: const TextStyle(fontSize: 12, color: kMutedTextColor),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in provider.progressions)
                        FilterChip(
                          label: Text(p.name),
                          selected: parcours.contains(p.id),
                          onSelected: (sel) => setSt(() => sel ? parcours.add(p.id) : parcours.remove(p.id)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Générer'),
            onPressed: statuses.isEmpty
                ? null
                : () => Navigator.pop(
                      dialogContext,
                      WorkPlanOptions(
                        showStatus: showStatus,
                        showCheckboxes: showCheckboxes,
                        // Tous coches : pas de filtre (un niveau ajoute plus tard reste inclus).
                        statusKeys: statuses.length == statusOptions.length ? null : Set.of(statuses),
                        parcoursIds: parcours.isEmpty ? null : Set.of(parcours),
                        onlyPlannedThisWeek: onlyPlanned,
                      ),
                    ),
          ),
        ],
      ),
    ),
  );
}
