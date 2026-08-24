import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/activity_type.dart';
import '../data/eduscol_data.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';

/// Formulaire plein écran de création / édition d'un atelier, accessible
/// depuis l'onglet « Espaces & Ateliers » des Réglages.
class AtelierEditScreen extends StatefulWidget {
  final ActivityType? activityType;
  final String? preselectedSpaceId;

  const AtelierEditScreen({
    super.key,
    this.activityType,
    this.preselectedSpaceId,
  });

  @override
  State<AtelierEditScreen> createState() => _AtelierEditScreenState();
}

class _AtelierEditScreenState extends State<AtelierEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _customDomaineCtrl;
  late TextEditingController _customObjectiveCtrl;

  late String _spaceId;
  late String _color;
  late String? _selectedDomainId;
  late String _selectedLevelFilter;
  late bool _isObligatory;
  late List<String> _selectedObjectives;
  late String? _iconName;
  late List<String> _obligatoryGroups;
  late List<String> _photoPaths;
  late Map<String, String> _photoCaptions;
  late String? _imagePath;
  final ScrollController _objectivesScrollCtrl = ScrollController();
  String _objectiveQuery = '';

  final List<String> _colors = [
    '#FF7043', '#4E9F3D', '#7E57C2', '#FFA726', '#42A5F5',
    '#8D6E63', '#E91E63', '#00BCD4', '#673AB7', '#FF5722'
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final act = widget.activityType;

    _nameCtrl = TextEditingController(text: act?.name ?? '');
    _descCtrl = TextEditingController(text: act?.description ?? '');
    _customDomaineCtrl = TextEditingController();
    _customObjectiveCtrl = TextEditingController();

    _spaceId = widget.preselectedSpaceId ?? act?.spaceId ?? (provider.spaces.isNotEmpty ? provider.spaces.first.id : '');
    _color = act?.colorHex ?? '#4E9F3D';
    _isObligatory = act?.isObligatory ?? false;

    // L'identifiant enregistre fait foi ; la recherche par titre ne sert plus
    // que pour un atelier anterieur a la migration.
    _selectedDomainId = act?.domaineId ??
        (EduscolData.domains.any((d) => d.title == act?.domaine)
            ? EduscolData.domains.firstWhere((d) => d.title == act?.domaine).id
            : (act?.domaine.isNotEmpty == true ? 'custom' : 'none'));

    if (_selectedDomainId == 'custom') {
      _customDomaineCtrl.text = act?.domaine ?? '';
    }

    _selectedLevelFilter = 'Tous';
    _selectedObjectives = List<String>.from(act?.objectifs ?? []);
    _iconName = act?.iconName;
    _obligatoryGroups = List<String>.from(act?.obligatoryGroups ?? []);
    _photoPaths = List<String>.from(act?.photoPaths ?? []);
    _photoCaptions = Map<String, String>.from(act?.photoCaptions ?? {});
    _imagePath = act?.imagePath;
  }

  Future<void> _editPhotoCaption(String relPath) async {
    final ctrl = TextEditingController(text: _photoCaptions[relPath] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Commentaire de la photo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ce que montre la photo, la consigne, le matériel...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.isEmpty) {
        _photoCaptions.remove(relPath);
      } else {
        _photoCaptions[relPath] = result;
      }
    });
  }

  /// Sections proposees pour le ciblage : celles definies dans les parametres,
  /// completees d'un eventuel ciblage devenu obsolete pour qu'il reste
  /// decochable.
  List<String> _knownGroups(AppStateProvider provider) {
    final groups = List<String>.from(provider.sections);
    for (final g in _obligatoryGroups) {
      if (!groups.contains(g)) groups.add(g);
    }
    return groups;
  }

  Future<void> _addAtelierPhotos() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Sélectionner de la galerie (multiples)'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final images = await picker.pickMultiImage(
                      maxWidth: AppStateProvider.photoMaxSize.toDouble(),
                      maxHeight: AppStateProvider.photoMaxSize.toDouble(),
                      imageQuality: AppStateProvider.photoQuality,
                    );
                    for (final img in images) {
                      final relPath = await provider.saveXFileToDocs(img, 'ateliers');
                      if (mounted) setState(() => _photoPaths.add(relPath));
                    }
                  } catch (e) {
                    debugPrint('Erreur selection photos atelier: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final relPath = await provider.pickAndSavePhoto(
                    source: ImageSource.camera,
                    subDir: 'ateliers',
                  );
                  if (relPath != null && mounted) {
                    setState(() => _photoPaths.add(relPath));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customDomaineCtrl.dispose();
    _customObjectiveCtrl.dispose();
    _objectivesScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final query = _objectiveQuery.trim().toLowerCase();
    final availableEduscolObjectives = EduscolData.objectives.where((obj) {
      final matchDomain = obj.domainId == _selectedDomainId;
      final matchLevel = _selectedLevelFilter == 'Tous' || obj.level == _selectedLevelFilter;
      final matchQuery = query.isEmpty || obj.text.toLowerCase().contains(query);
      return matchDomain && matchLevel && matchQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activityType == null ? 'Nouveau type d\'atelier' : 'Modifier l\'atelier'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E9F3D),
                foregroundColor: Colors.white,
              ),
              onPressed: _saveAtelier,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Informations de base
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📌 Informations Générales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'atelier *',
                        hintText: 'Ex: Peinture à la gouache',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.palette),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: provider.spaces.any((s) => s.id == _spaceId) ? _spaceId : null,
                      decoration: const InputDecoration(
                        labelText: 'Espace de la classe *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.space_dashboard),
                      ),
                      items: provider.spaces.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _spaceId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.stars, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Atelier Obligatoire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      subtitle: const Text(
                        'Cet atelier doit être réalisé par les élèves concernés.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _isObligatory,
                      activeColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setState(() => _isObligatory = val),
                    ),
                    if (_isObligatory) ...[
                      const SizedBox(height: 4),
                      const Text('Sections concernées :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        _obligatoryGroups.isEmpty
                            ? 'Aucune section sélectionnée : obligatoire pour toute la classe.'
                            : 'Obligatoire uniquement pour ${_obligatoryGroups.length} section(s).',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final groups = _knownGroups(provider);
                          if (groups.isEmpty) {
                            return const Text(
                              'Aucune section définie. Ajoutez-en dans Paramètres > Ma classe.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: groups.map((g) {
                              final isSelected = _obligatoryGroups.contains(g);
                              return FilterChip(
                                label: Text(g, style: const TextStyle(fontSize: 13)),
                                selected: isSelected,
                                selectedColor: const Color(0xFF4E9F3D).withOpacity(0.2),
                                checkmarkColor: const Color(0xFF4E9F3D),
                                onSelected: (sel) {
                                  setState(() {
                                    if (sel) {
                                      _obligatoryGroups.add(g);
                                    } else {
                                      _obligatoryGroups.remove(g);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Domaine & Objectifs Éduscol
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📚 Domaine & Objectifs Éduscol (Cycle 1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: (_selectedDomainId == 'custom' || _selectedDomainId == 'none' || EduscolData.domains.any((d) => d.id == _selectedDomainId)) ? _selectedDomainId : 'none',
                      decoration: const InputDecoration(
                        labelText: 'Domaine d\'apprentissage Éduscol (Optionnel)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'none',
                          child: Text('-- Aucun domaine sélectionné --', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        ...EduscolData.domains.map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        )),
                        const DropdownMenuItem(
                          value: 'custom',
                          child: Text('➕ Autre (Saisie personnalisée)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDomainId = val);
                        }
                      },
                    ),

                    if (_selectedDomainId == 'custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customDomaineCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom du domaine personnalisé',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    if (_selectedDomainId != 'custom' && _selectedDomainId != 'none') ...[
                      // Le libelle sur sa propre ligne et un Wrap plutot qu'un
                      // defilement horizontal : sur telephone, partager la Row
                      // avec le titre ne laissait qu'une bande etroite.
                      const Text('🎯 Tranche d\'âge / Niveau :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Tous', 'PS', 'MS', 'GS'].map((lvl) {
                          final isSelected = _selectedLevelFilter == lvl;
                          return ChoiceChip(
                            label: Text(
                              lvl == 'PS' ? 'PS (2-4 ans)' : lvl == 'MS' ? 'MS (4-5 ans)' : lvl == 'GS' ? 'GS (5-6 ans)' : 'Tous',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF4E9F3D),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedLevelFilter = lvl);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Rechercher un objectif...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _objectiveQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _objectiveQuery = ''),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) => setState(() => _objectiveQuery = val),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        // Liste plus haute et barre de defilement toujours
                        // visible : a 220 px sans ascenseur, on ne voyait pas
                        // ou l'on se situait dans le referentiel.
                        constraints: const BoxConstraints(maxHeight: 380),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: availableEduscolObjectives.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Aucun objectif ne correspond à ce filtre.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            : Scrollbar(
                                controller: _objectivesScrollCtrl,
                                thumbVisibility: true,
                                child: ListView.separated(
                                controller: _objectivesScrollCtrl,
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(right: 8),
                                itemCount: availableEduscolObjectives.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final obj = availableEduscolObjectives[idx];
                                  final isChecked = _selectedObjectives.contains(obj.text);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(obj.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    subtitle: Text('Niveau Éduscol : ${obj.level}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    value: isChecked,
                                    activeColor: const Color(0xFF4E9F3D),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          if (!_selectedObjectives.contains(obj.text)) {
                                            _selectedObjectives.add(obj.text);
                                          }
                                        } else {
                                          _selectedObjectives.remove(obj.text);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text('🏁 Objectifs retenus pour cet atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_selectedObjectives.isEmpty)
                      const Text('Aucun objectif sélectionné.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedObjectives.map((objText) {
                          return Chip(
                            label: Text(objText, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedObjectives.remove(objText);
                              });
                            },
                            backgroundColor: const Color(0xFF4E9F3D).withOpacity(0.15),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customObjectiveCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ajouter un objectif sur-mesure',
                              hintText: 'Ex: Utiliser des ciseaux à bouts ronds',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            final txt = _customObjectiveCtrl.text.trim();
                            if (txt.isNotEmpty) {
                              setState(() {
                                if (!_selectedObjectives.contains(txt)) {
                                  _selectedObjectives.add(txt);
                                }
                                _customObjectiveCtrl.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add_circle, color: Color(0xFF4E9F3D), size: 36),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Description & Couleur
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎨 Description & Identité Visuelle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description de l\'activité (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text('Couleur de l\'atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors.map((c) {
                        final isSelected = c == _color;
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hexToColor(c),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: hexToColor(c), blurRadius: 8)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text('Icône de l\'atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: hexToColor(_color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconForName(_iconName, fallback: Icons.category),
                            color: hexToColor(_color),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showAppIconPicker(context, _iconName);
                              if (picked != null && mounted) {
                                setState(() => _iconName = picked.isEmpty ? null : picked);
                              }
                            },
                            icon: const Icon(Icons.emoji_symbols),
                            label: Text(_iconName == null ? 'Choisir une icône' : 'Icône : $_iconName'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Expanded(
                          child: Text('Photos de l\'atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Text('${_photoPaths.length} photo(s)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Elles illustrent l\'atelier et sont reprises dans l\'export PDF.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 132,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: _addAtelierPhotos,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).dividerColor),
                              ),
                              child: Icon(Icons.add_a_photo,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant, size: 26),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ..._photoPaths.asMap().entries.map((entry) {
                            final relPath = entry.value;
                            final absPath = provider.getAbsolutePath(relPath);
                            final caption = _photoCaptions[relPath];
                            final hasCaption = caption != null && caption.trim().isNotEmpty;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: absPath != null && File(absPath).existsSync()
                                            ? Image.file(File(absPath), width: 88, height: 88, fit: BoxFit.cover)
                                            : Container(
                                                width: 88,
                                                height: 88,
                                                color: Theme.of(context).colorScheme.surfaceVariant,
                                                child: const Icon(Icons.broken_image, size: 24),
                                              ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _photoPaths.removeAt(entry.key);
                                            _photoCaptions.remove(relPath);
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 88,
                                    child: TextButton.icon(
                                      onPressed: () => _editPhotoCaption(relPath),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(hasCaption ? Icons.edit_note : Icons.add_comment, size: 14),
                                      label: Text(
                                        hasCaption ? caption.trim() : 'Commenter',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Le bouton d'enregistrement est celui de la barre du haut :
            // il reste atteignable sans parcourir tout le formulaire.
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _saveAtelier() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un nom d\'atelier.'), backgroundColor: Colors.red),
      );
      return;
    }

    String finalDomaine = '';
    String? finalDomaineId;
    if (_selectedDomainId == 'custom') {
      finalDomaine = _customDomaineCtrl.text.trim();
    } else if (_selectedDomainId != null && _selectedDomainId != 'none') {
      final dom = EduscolData.domains.firstWhere((d) => d.id == _selectedDomainId, orElse: () => EduscolData.domains.first);
      finalDomaine = dom.title;
      finalDomaineId = dom.id;
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    // Un atelier existant garde sa position tant qu'il reste dans le meme
    // espace ; un atelier nouveau (ou deplace vers un autre espace) en mode
    // progression s'ajoute en fin de liste plutot que de garder un rang
    // hors contexte.
    final keepsPreviousPosition =
        widget.activityType != null && widget.activityType!.spaceId == _spaceId;
    final position = (keepsPreviousPosition ? widget.activityType?.position : null) ??
        (provider.spaceById(_spaceId)?.isProgression == true
            ? provider.nextPositionForSpace(_spaceId)
            : -1);
    final newType = ActivityType(
      id: widget.activityType?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      spaceId: _spaceId,
      colorHex: _color,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      // imagePath n'etait pas repris : modifier un atelier effacait jusqu'ici
      // son illustration principale.
      imagePath: _imagePath,
      domaine: finalDomaine,
      domaineId: finalDomaineId,
      objectifs: _selectedObjectives,
      isObligatory: _isObligatory,
      iconName: _iconName,
      photoPaths: _photoPaths,
      photoCaptions: _photoCaptions,
      obligatoryGroups: _isObligatory ? _obligatoryGroups : const [],
      position: position,
    );

    provider.saveActivityType(newType);
    Navigator.pop(context);
  }
}
