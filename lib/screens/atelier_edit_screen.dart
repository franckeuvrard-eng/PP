import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/photo_thumb.dart';
import '../providers/app_provider.dart';
import '../models/activity_type.dart';
import '../data/eduscol_data.dart';
import '../services/clipboard_image_service.dart';
import '../utils/color_utils.dart';
import '../widgets/age_chip.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/icon_swatch_picker.dart';

/// Formulaire plein écran de création / édition d'un atelier, accessible
/// depuis les onglets « Espaces & Ateliers » et « Progressions » des
/// Réglages. Un atelier est rangé soit dans un espace, soit dans une
/// progression (jalon), jamais les deux.
class AtelierEditScreen extends StatefulWidget {
  final ActivityType? activityType;
  final String? preselectedSpaceId;
  final String? preselectedProgressionId;

  const AtelierEditScreen({
    super.key,
    this.activityType,
    this.preselectedSpaceId,
    this.preselectedProgressionId,
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
  late String _progressionId;

  /// Rangé dans une progression (jalon) plutôt que dans un espace.
  late bool _inProgression;
  late String _color;
  late String? _selectedDomainId;

  /// Cycle du programme dont on parcourt les domaines.
  late int _cycle;

  /// Sous-domaine de l'atelier, enregistre avec lui ; filtre aussi la liste
  /// des objectifs. Null : non precise (tous les objectifs du domaine).
  String? _selectedSubdomainId;
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

  /// Sections repliees par defaut sur un atelier neuf (pour reduire le
  /// defilement) mais depliees d'emblee si elles contiennent deja des
  /// donnees, pour ne rien cacher a l'edition.
  late final bool _domainSectionHasContent;
  late final bool _visualSectionHasContent;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final act = widget.activityType;

    _nameCtrl = TextEditingController(text: act?.name ?? '');
    _descCtrl = TextEditingController(text: act?.description ?? '');
    _customDomaineCtrl = TextEditingController();
    _customObjectiveCtrl = TextEditingController();

    _inProgression = widget.preselectedProgressionId != null ||
        (widget.preselectedSpaceId == null && (act?.inProgression ?? false));
    _spaceId = widget.preselectedSpaceId ??
        (act != null && act.spaceId.isNotEmpty ? act.spaceId : null) ??
        (provider.spaces.isNotEmpty ? provider.spaces.first.id : '');
    _progressionId = widget.preselectedProgressionId ??
        act?.progressionId ??
        (provider.progressions.isNotEmpty ? provider.progressions.first.id : '');
    _color = act?.colorHex ?? '#4E9F3D';
    _isObligatory = act?.isObligatory ?? false;

    // L'identifiant enregistre fait foi ; la recherche par titre ne sert plus
    // que pour un atelier anterieur a la migration.
    _selectedDomainId = act?.domaineId ??
        EduscolData.domainByTitle(act?.domaine ?? '')?.id ??
        (act?.domaine.isNotEmpty == true ? 'custom' : 'none');
    _cycle = EduscolData.domainById(_selectedDomainId)?.cycle ?? EduscolData.cycles.first;

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

    // Garde seulement un sous-domaine qui appartient bien au domaine.
    _selectedSubdomainId =
        EduscolData.subdomainById(act?.sousDomaineId)?.domainId == _selectedDomainId
            ? act?.sousDomaineId
            : null;

    _domainSectionHasContent =
        act != null && (act.domaine.isNotEmpty || act.objectifs.isNotEmpty);
    _visualSectionHasContent = act != null &&
        ((act.description?.trim().isNotEmpty ?? false) ||
            act.photoPaths.isNotEmpty ||
            act.iconName != null);
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
    ctrl.dispose();
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

  bool _pasting = false;

  /// Colle l'image du presse-papiers (copiee depuis un site, une autre app...).
  Future<void> _pastePhoto() async {
    if (_pasting) return;
    setState(() => _pasting = true);
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final result = await ClipboardImageService.paste(provider, 'ateliers');
    if (!mounted) return;
    setState(() {
      _pasting = false;
      if (result.relPath != null) _photoPaths.add(result.relPath!);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.error ?? 'Image collée.'),
      backgroundColor: result.error == null ? const Color(0xFF4E9F3D) : Colors.orange,
    ));
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
                      final relPath =
                          await provider.saveXFileToDocs(img, 'ateliers');
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
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: const Text('Coller une image'),
                subtitle: const Text('Copiée depuis internet ou une autre application'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pastePhoto();
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
      final matchSub = _selectedSubdomainId == null || obj.subdomainId == _selectedSubdomainId;
      final matchLevel =
          _selectedLevelFilter == 'Tous' || obj.level == _selectedLevelFilter;
      final matchQuery =
          query.isEmpty || obj.text.toLowerCase().contains(query);
      return matchDomain && matchSub && matchLevel && matchQuery;
    }).toList();

    // Liste affichee : un en-tete (String) a chaque changement de
    // sous-domaine ou de theme, puis les objectifs (EduscolObjective).
    final objectiveRows = <Object>[];
    String? lastHeader;
    for (final obj in availableEduscolObjectives) {
      final sub = EduscolData.subdomains.firstWhere((s) => s.id == obj.subdomainId).title;
      final header = [if (_selectedSubdomainId == null) sub, if (obj.theme != null) obj.theme!]
          .join(' › ');
      if (header.isNotEmpty && header != lastHeader) objectiveRows.add(header);
      lastHeader = header;
      objectiveRows.add(obj);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_inProgression
            ? (widget.activityType == null ? 'Nouvelle étape' : "Modifier l'étape")
            : (widget.activityType == null ? 'Nouvel atelier' : "Modifier l'atelier")),
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
                        labelText: _inProgression ? "Nom de l'étape *" : "Nom de l'atelier *",
                        hintText: _inProgression ? 'Ex: Couper une ligne droite' : 'Ex: Peinture à la gouache',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(_inProgression ? Icons.flag : Icons.palette),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_inProgression)
                      DropdownButtonFormField<String>(
                        // Champ pilote par le code : initialValue ne suivrait pas
                        // ses changements.
                        // ignore: deprecated_member_use
                        value: provider.spaces.any((s) => s.id == _spaceId)
                            ? _spaceId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Espace de la classe *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.space_dashboard),
                        ),
                        items: provider.spaces
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _spaceId = val);
                        },
                      )
                    else if (provider.progressions.isEmpty)
                      const Text(
                        "Aucun parcours : créez-en un dans Parcours › Gérer.",
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: provider.progressions.any((p) => p.id == _progressionId)
                            ? _progressionId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Parcours *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timeline),
                        ),
                        items: provider.progressions
                            .map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _progressionId = val);
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Une nouvelle étape s'ajoute en fin de parcours ; l'ordre se règle "
                        "dans Parcours › Gérer.",
                        style: TextStyle(fontSize: 11, color: kMutedTextColor),
                      ),
                    ],
                    // Les sections d'un parcours se choisissent sur le parcours,
                    // pas sur chacune de ses étapes.
                    if (!_inProgression) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.stars, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Plan de travail',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      subtitle: const Text(
                        'Cet atelier doit être réalisé par les élèves concernés.',
                        style: TextStyle(fontSize: 12, color: kMutedTextColor),
                      ),
                      value: _isObligatory,
                      activeThumbColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setState(() => _isObligatory = val),
                    ),
                    if (_isObligatory) ...[
                      const SizedBox(height: 4),
                      const Text('Sections concernées :',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        _obligatoryGroups.isEmpty
                            ? 'Aucune section sélectionnée : dans le plan de travail de toute la classe.'
                            : 'Dans le plan de travail de ${_obligatoryGroups.length} section(s) uniquement.',
                        style:
                            const TextStyle(fontSize: 12, color: kMutedTextColor),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final groups = _knownGroups(provider);
                          if (groups.isEmpty) {
                            return const Text(
                              'Aucune section définie. Ajoutez-en dans Paramètres > Ma classe.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: kMutedTextColor),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: groups.map((g) {
                              final isSelected = _obligatoryGroups.contains(g);
                              return FilterChip(
                                label: Text(g,
                                    style: const TextStyle(fontSize: 13)),
                                selected: isSelected,
                                selectedColor:
                                    const Color(0xFF4E9F3D).withValues(alpha: 0.2),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Domaine & Objectifs Éduscol
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                initiallyExpanded: _domainSectionHasContent,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                expandedAlignment: Alignment.centerLeft,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: const Text('📚 Domaine & Objectifs Éduscol',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                children: [
                  // Le cycle en premier : il determine les domaines proposes.
                  SegmentedButton<int>(
                    segments: [
                      for (final c in EduscolData.cycles)
                        ButtonSegment(value: c, label: Text(EduscolData.cycleLabel(c))),
                      if (!EduscolData.cycles.contains(2))
                        const ButtonSegment(
                            value: 2, enabled: false, label: Text('Cycle 2 · bientôt')),
                    ],
                    selected: {_cycle},
                    onSelectionChanged: (sel) => setState(() {
                      _cycle = sel.first;
                      if (EduscolData.domainById(_selectedDomainId)?.cycle != _cycle) {
                        _selectedDomainId = 'none';
                        _selectedSubdomainId = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // Champ pilote par le code : initialValue ne suivrait pas
                    // ses changements.
                    // ignore: deprecated_member_use
                    value: (_selectedDomainId == 'custom' ||
                            _selectedDomainId == 'none' ||
                            EduscolData.domainById(_selectedDomainId) != null)
                        ? _selectedDomainId
                        : 'none',
                    decoration: const InputDecoration(
                      labelText: 'Domaine d\'apprentissage (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('-- Aucun domaine sélectionné --',
                            style: TextStyle(fontSize: 13, color: kMutedTextColor)),
                      ),
                      for (final d in EduscolData.domainsForCycle(_cycle))
                        DropdownMenuItem(
                          value: d.id,
                          child: Text(d.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      // Domaine d'un ancien programme deja choisi : il reste
                      // affiche tant qu'on ne le change pas.
                      if (EduscolData.domainById(_selectedDomainId)?.legacy ?? false)
                        DropdownMenuItem(
                          value: _selectedDomainId,
                          child: Text(
                              '${EduscolData.domainById(_selectedDomainId)!.title} (ancien programme)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontStyle: FontStyle.italic)),
                        ),
                      const DropdownMenuItem(
                        value: 'custom',
                        child: Text('➕ Autre (Saisie personnalisée)',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedDomainId = val;
                          _selectedSubdomainId = null;
                        });
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
                  if (EduscolData.domainById(_selectedDomainId)?.legacy ?? false) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Ce domaine vient d\'un ancien programme. Choisissez un domaine actuel '
                      'pour voir ses objectifs ; les objectifs déjà retenus restent sur l\'atelier.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (EduscolData.subdomainsOf(_selectedDomainId ?? '').isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: _selectedSubdomainId,
                      decoration: const InputDecoration(
                        labelText: 'Sous-domaine',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.subdirectory_arrow_right),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Non précisé (tous les objectifs du domaine)',
                              style: TextStyle(fontSize: 13, color: kMutedTextColor)),
                        ),
                        for (final s in EduscolData.subdomainsOf(_selectedDomainId!))
                          DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                      onChanged: (val) => setState(() => _selectedSubdomainId = val),
                    ),
                    const SizedBox(height: 16),
                    // Le libelle sur sa propre ligne et un Wrap plutot qu'un
                    // defilement horizontal : sur telephone, partager la Row
                    // avec le titre ne laissait qu'une bande etroite.
                    const Text('🎯 Âge / niveau :',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Tous', ...EduscolData.levels[_cycle] ?? const <String>[]].map((lvl) {
                        final isSelected = _selectedLevelFilter == lvl;
                        final age = EduscolData.ageLabel(lvl);
                        return ChoiceChip(
                          label: Text(
                            age == null ? lvl : '$age ($lvl)',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          selected: isSelected,
                          selectedColor: lvl == 'Tous'
                              ? const Color(0xFF4E9F3D)
                              : AgeChip.colorFor(lvl),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
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
                                onPressed: () =>
                                    setState(() => _objectiveQuery = ''),
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
                      constraints: const BoxConstraints(maxHeight: 420),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: objectiveRows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'Aucun objectif ne correspond à ce filtre.',
                                  style: TextStyle(
                                      fontSize: 12, color: kMutedTextColor)),
                            )
                          : Scrollbar(
                              controller: _objectivesScrollCtrl,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _objectivesScrollCtrl,
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(right: 8),
                                itemCount: objectiveRows.length,
                                itemBuilder: (context, idx) {
                                  final row = objectiveRows[idx];
                                  // En-tete de sous-domaine / theme.
                                  if (row is String) {
                                    return Container(
                                      width: double.infinity,
                                      color: const Color(0xFF4E9F3D).withValues(alpha: 0.08),
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                                      child: Text(row,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: kAccessibleGreenText)),
                                    );
                                  }
                                  final obj = row as EduscolObjective;
                                  final isChecked =
                                      _selectedObjectives.contains(obj.text);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(obj.text,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: AgeChip(level: obj.level),
                                      ),
                                    ),
                                    value: isChecked,
                                    activeColor: const Color(0xFF4E9F3D),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          if (!_selectedObjectives
                                              .contains(obj.text)) {
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
                  const Text('🏁 Objectifs retenus pour cet atelier :',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_selectedObjectives.isEmpty)
                    const Text('Aucun objectif sélectionné.',
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: kMutedTextColor))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedObjectives.map((objText) {
                        final levels = EduscolData.levelsForText(objText);
                        return Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final l in levels) ...[
                                AgeChip(level: l, compact: true),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(objText,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedObjectives.remove(objText);
                            });
                          },
                          backgroundColor:
                              const Color(0xFF4E9F3D).withValues(alpha: 0.15),
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
                        icon: const Icon(Icons.add_circle,
                            color: Color(0xFF4E9F3D), size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Description & Couleur
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                initiallyExpanded: _visualSectionHasContent,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                expandedAlignment: Alignment.centerLeft,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: const Text('🎨 Description & Identité Visuelle',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                children: [
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description de l\'activité (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text('Couleur de l\'atelier :',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ColorSwatchPicker(
                    selectedHex: _color,
                    onChanged: (hex) => setState(() => _color = hex),
                  ),
                  const SizedBox(height: 16),
                  const Text('Icône de l\'atelier :',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  IconSwatchPicker(
                    iconName: _iconName,
                    previewColor: hexToColor(_color),
                    fallback: Icons.category,
                    onChanged: (val) {
                      if (!mounted) return;
                      setState(() => _iconName = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Photos de l\'atelier :',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Text('${_photoPaths.length} photo(s)',
                          style: const TextStyle(
                              fontSize: 12, color: kMutedTextColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elles illustrent l\'atelier et sont reprises dans l\'export PDF.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor),
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
                              color:
                                  Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                            ),
                            child: Icon(Icons.add_a_photo,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 26),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Coller en un geste : image copiee sur un site.
                        Tooltip(
                          message: 'Coller une image copiée',
                          child: GestureDetector(
                            onTap: _pastePhoto,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).dividerColor),
                              ),
                              child: _pasting
                                  ? const Center(
                                      child: SizedBox(
                                          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.content_paste,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                                        const SizedBox(height: 4),
                                        const Text('Coller', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ..._photoPaths.asMap().entries.map((entry) {
                          final relPath = entry.value;
                          final absPath = provider.getAbsolutePath(relPath);
                          final caption = _photoCaptions[relPath];
                          final hasCaption =
                              caption != null && caption.trim().isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: absPath != null &&
                                              File(absPath).existsSync()
                                          ? PhotoThumb(path: absPath, size: 88, radius: 16)
                                          : Container(
                                              width: 88,
                                              height: 88,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  size: 24),
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
                                          decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white),
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(
                                        hasCaption
                                            ? Icons.edit_note
                                            : Icons.add_comment,
                                        size: 14),
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
        const SnackBar(
            content: Text('Veuillez saisir un nom.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    String finalDomaine = '';
    String? finalDomaineId;
    if (_selectedDomainId == 'custom') {
      finalDomaine = _customDomaineCtrl.text.trim();
    } else if (_selectedDomainId != null && _selectedDomainId != 'none') {
      // Domaine inconnu de cette version (donnee venue d'un appareil plus
      // recent) : on le garde tel quel plutot que de le remplacer.
      final dom = EduscolData.domainById(_selectedDomainId);
      finalDomaine = dom?.title ?? widget.activityType?.domaine ?? '';
      finalDomaineId = dom?.id ?? _selectedDomainId;
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final inProgression = _inProgression && provider.progressionById(_progressionId) != null;
    if (_inProgression && !inProgression) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Choisissez un parcours.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    // Un jalon garde son rang tant qu'il reste dans la meme progression ; un
    // nouveau (ou venu d'ailleurs) s'ajoute en fin de fil.
    final keepsPreviousPosition = inProgression &&
        widget.activityType?.progressionId == _progressionId;
    final position = !inProgression
        ? -1
        : (keepsPreviousPosition
            ? widget.activityType!.position
            : provider.nextPositionInProgression(_progressionId));
    final newType = ActivityType(
      id: widget.activityType?.id ??
          'act_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      spaceId: inProgression ? '' : _spaceId,
      progressionId: inProgression ? _progressionId : null,
      colorHex: _color,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      // imagePath n'etait pas repris : modifier un atelier effacait jusqu'ici
      // son illustration principale.
      imagePath: _imagePath,
      domaine: finalDomaine,
      domaineId: finalDomaineId,
      sousDomaineId: EduscolData.subdomainById(_selectedSubdomainId)?.domainId == finalDomaineId
          ? _selectedSubdomainId
          : null,
      objectifs: _selectedObjectives,
      isObligatory: _isObligatory,
      iconName: _iconName,
      photoPaths: _photoPaths,
      photoCaptions: _photoCaptions,
      obligatoryGroups: _isObligatory ? _obligatoryGroups : const [],
      position: position,
      isDisabled: widget.activityType?.isDisabled ?? false,
    );

    provider.saveActivityType(newType);
    Navigator.pop(context);
  }
}
