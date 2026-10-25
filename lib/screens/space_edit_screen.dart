import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/progression.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/icon_swatch_picker.dart';

/// Formulaire plein écran de création / édition d'un espace de la classe
/// (onglet « Espaces & Ateliers ») ou d'une progression (onglet
/// « Progressions ») : memes champs, plus le seuil de passage pour une
/// progression.
///
/// Miroir de [AtelierEditScreen] : un espace et un atelier s'éditent
/// désormais de la même façon (page dédiée), plutôt que l'un en popup et
/// l'autre en page — l'incohérence n'avait pas de raison fonctionnelle.
class SpaceEditScreen extends StatefulWidget {
  final Space? space;
  final Progression? progression;

  /// Edition d'une progression plutot que d'un espace.
  final bool forProgression;

  const SpaceEditScreen({super.key, this.space})
      : progression = null,
        forProgression = false;

  const SpaceEditScreen.progression({super.key, this.progression})
      : space = null,
        forProgression = true;

  @override
  State<SpaceEditScreen> createState() => _SpaceEditScreenState();
}

class _SpaceEditScreenState extends State<SpaceEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late String _color;
  late String? _iconName;
  late String? _progressionMinStatusId;
  late List<String> _targetGroups;

  bool get _p => widget.forProgression;
  bool get _isNew => _p ? widget.progression == null : widget.space == null;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final space = widget.space;
    final prog = widget.progression;

    _nameCtrl = TextEditingController(text: prog?.name ?? space?.name ?? '');
    _descCtrl = TextEditingController(text: prog?.description ?? space?.description ?? '');
    _color = prog?.colorHex ?? space?.colorHex ?? '#4E9F3D';
    _iconName = prog?.iconName ?? space?.iconName;
    _progressionMinStatusId = prog?.minStatusId ??
        (provider.evaluationStatuses.isNotEmpty
            ? provider.evaluationStatuses.last.id
            : null);
    _targetGroups = List<String>.from(prog?.targetGroups ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _saveSpace() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez saisir un nom.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    if (_p) {
      provider.saveProgression(Progression(
        id: widget.progression?.id ?? 'prog_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameCtrl.text.trim(),
        colorHex: _color,
        description: description,
        iconName: _iconName,
        minStatusId: _progressionMinStatusId,
        targetGroups: _targetGroups,
      ));
    } else {
      provider.addOrUpdateSpace(Space(
        id: widget.space?.id ?? 'space_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameCtrl.text.trim(),
        colorHex: _color,
        description: description,
        iconName: _iconName,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_p
                ? (_isNew ? 'Nouveau parcours' : 'Modifier le parcours')
                : (_isNew ? 'Nouvel espace' : 'Modifier l\'espace')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Enregistrer',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E9F3D),
                foregroundColor: Colors.white,
              ),
              onPressed: _saveSpace,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1 : Informations générales
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📌 Informations Générales',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: _p ? 'Nom du parcours *' : 'Nom de l\'espace *',
                        hintText: _p ? 'Ex: Découpage' : 'Ex: Coin Arts Visuels',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(_p ? Icons.timeline : Icons.space_dashboard),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2 : seuil de passage (progressions seulement)
            if (_p) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seuil de passage',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        "Les étapes se font dans l'ordre : une étape reste verrouillée pour un élève "
                        "tant que la précédente n'a pas atteint ce niveau.",
                        style: TextStyle(fontSize: 12),
                      ),
                      if (provider.evaluationStatuses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "Aucun niveau d'évaluation n'existe : aucune étape ne pourra être "
                            "débloquée. Créez-en au moins un dans Paramètres.",
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          // Champ pilote par le code : initialValue ne suivrait pas ses
                          // changements.
                          // ignore: deprecated_member_use
                          value: provider.evaluationStatuses
                                  .any((s) => s.id == _progressionMinStatusId)
                              ? _progressionMinStatusId
                              : null,
                          decoration: const InputDecoration(
                            labelText: "Niveau à atteindre pour passer à l'étape suivante",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final st in provider.evaluationStatuses)
                              DropdownMenuItem(value: st.id, child: Text(st.label)),
                          ],
                          onChanged: (val) => setState(() => _progressionMinStatusId = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionsCard(provider),
              const SizedBox(height: 16),
            ],

            // Section 3 : Description & Identité Visuelle
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎨 Identité Visuelle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(_p ? 'Couleur du parcours :' : 'Couleur de l\'espace :',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ColorSwatchPicker(
                      selectedHex: _color,
                      onChanged: (hex) => setState(() => _color = hex),
                    ),
                    const SizedBox(height: 16),
                    Text(_p ? 'Icône du parcours :' : 'Icône de l\'espace :',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    IconSwatchPicker(
                      iconName: _iconName,
                      previewColor: hexToColor(_color),
                      fallback: _p ? Icons.timeline : Icons.space_dashboard,
                      onChanged: (val) {
                        if (!mounted) return;
                        setState(() => _iconName = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Sections qui suivent le parcours. Celles qui n'existent plus dans les
  /// Parametres restent affichees pour pouvoir etre decochees.
  Widget _sectionsCard(AppStateProvider provider) {
    final groups = List<String>.from(provider.sections);
    for (final g in _targetGroups) {
      if (!groups.contains(g)) groups.add(g);
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sections concernées',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              _targetGroups.isEmpty
                  ? 'Aucune section cochée : toute la classe suit ce parcours.'
                  : 'Seules ces ${_targetGroups.length} section(s) suivent ce parcours '
                      '(plan de travail, suivi et rapport des parcours).',
              style: const TextStyle(fontSize: 12, color: kMutedTextColor),
            ),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              const Text(
                'Aucune section définie. Ajoutez-en dans Paramètres > Profil Classe.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: kMutedTextColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in groups)
                    FilterChip(
                      label: Text(g, style: const TextStyle(fontSize: 13)),
                      selected: _targetGroups.contains(g),
                      selectedColor: const Color(0xFF4E9F3D).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF4E9F3D),
                      onSelected: (sel) => setState(() {
                        sel ? _targetGroups.add(g) : _targetGroups.remove(g);
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
