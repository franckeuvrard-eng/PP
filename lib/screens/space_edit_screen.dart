import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';
import '../utils/color_utils.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/icon_swatch_picker.dart';

/// Formulaire plein écran de création / édition d'un espace de la classe,
/// accessible depuis l'onglet « Espaces & Ateliers » des Réglages.
///
/// Miroir de [AtelierEditScreen] : un espace et un atelier s'éditent
/// désormais de la même façon (page dédiée), plutôt que l'un en popup et
/// l'autre en page — l'incohérence n'avait pas de raison fonctionnelle.
class SpaceEditScreen extends StatefulWidget {
  final Space? space;

  const SpaceEditScreen({super.key, this.space});

  @override
  State<SpaceEditScreen> createState() => _SpaceEditScreenState();
}

class _SpaceEditScreenState extends State<SpaceEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late String _color;
  late String? _iconName;
  late bool _isProgression;
  late String? _progressionMinStatusId;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final space = widget.space;

    _nameCtrl = TextEditingController(text: space?.name ?? '');
    _descCtrl = TextEditingController(text: space?.description ?? '');
    _color = space?.colorHex ?? '#4E9F3D';
    _iconName = space?.iconName;
    _isProgression = space?.isProgression ?? false;
    _progressionMinStatusId = space?.progressionMinStatusId ??
        (provider.evaluationStatuses.isNotEmpty
            ? provider.evaluationStatuses.last.id
            : null);
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
            content: Text('Veuillez saisir un nom d\'espace.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final newSpace = Space(
      id: widget.space?.id ?? 'space_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      colorHex: _color,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      iconName: _iconName,
      isProgression: _isProgression,
      progressionMinStatusId: _isProgression
          ? _progressionMinStatusId
          : widget.space?.progressionMinStatusId,
    );
    provider.addOrUpdateSpace(newSpace);
    if (_isProgression) {
      provider.setSpaceProgression(newSpace.id, true,
          minStatusId: _progressionMinStatusId);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.space == null ? 'Nouvel espace' : 'Modifier l\'espace'),
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
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'espace *',
                        hintText: 'Ex: Coin Arts Visuels',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.space_dashboard),
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

            // Section 2 : Mode progression
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔒 Progression',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mode progression (ordre imposé)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text(
                        "Les ateliers de cet espace doivent être faits dans l'ordre : un atelier reste verrouillé tant que les précédents n'ont pas atteint le statut minimum choisi.",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isProgression,
                      activeColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setState(() => _isProgression = val),
                    ),
                    if (_isProgression && provider.evaluationStatuses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "⚠️ Aucun niveau d'évaluation n'existe : aucun atelier ne pourra jamais être débloqué. Créez-en au moins un dans Réglages.",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (_isProgression &&
                        provider.evaluationStatuses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: provider.evaluationStatuses
                                .any((s) => s.id == _progressionMinStatusId)
                            ? _progressionMinStatusId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Statut minimum pour débloquer le suivant',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: provider.evaluationStatuses.map((s) {
                          return DropdownMenuItem(
                              value: s.id, child: Text(s.label));
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _progressionMinStatusId = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                    const Text('Couleur de l\'espace :',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ColorSwatchPicker(
                      selectedHex: _color,
                      onChanged: (hex) => setState(() => _color = hex),
                    ),
                    const SizedBox(height: 16),
                    const Text('Icône de l\'espace :',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    IconSwatchPicker(
                      iconName: _iconName,
                      previewColor: hexToColor(_color),
                      fallback: Icons.space_dashboard,
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
}
