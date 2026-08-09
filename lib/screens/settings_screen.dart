import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/class_settings.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../data/eduscol_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _classNameController;
  late TextEditingController _teacherController;
  late TextEditingController _atsemController;
  late TextEditingController _schoolNameController;
  late TextEditingController _schoolYearController;

  String _selectedLevel = 'PS';
  String? _classLogoPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final settings = provider.classSettings;

    _classNameController = TextEditingController(text: settings.name);
    _teacherController = TextEditingController(text: settings.teacher);
    _atsemController = TextEditingController(text: settings.atsem ?? '');
    _schoolNameController = TextEditingController(text: settings.schoolName ?? '');
    _schoolYearController = TextEditingController(text: settings.schoolYear);
    _selectedLevel = settings.level;
    _classLogoPath = settings.logoPath;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classNameController.dispose();
    _teacherController.dispose();
    _atsemController.dispose();
    _schoolNameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // TabBar only
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF4E9F3D),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4E9F3D),
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'Profil Classe'),
            Tab(icon: Icon(Icons.space_dashboard), text: 'Espaces & Ateliers'),
            Tab(icon: Icon(Icons.brightness_6), text: 'Apparence'),
            Tab(icon: Icon(Icons.security), text: 'Sauvegarde & Sécurité'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClassProfileTab(provider),
          _buildSpacesAndWorkshopsTab(provider),
          _buildAppearanceTab(provider),
          _buildSecurityBackupTab(provider),
        ],
      ),
    );
  }

  // ─────────────────── TAB 1 : PROFIL CLASSE ───────────────────
  Widget _buildClassProfileTab(AppStateProvider provider) {
    final absoluteLogoPath = provider.getAbsolutePath(_classLogoPath);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏫 Profil & Identité de la Classe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Ces informations seront affichées sur les livrets et exports PDF.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // Logo / Photo de classe
          Center(
            child: GestureDetector(
              onTap: () async {
                final relPath = await provider.pickAndSavePhoto(
                  source: ImageSource.gallery,
                  subDir: 'settings',
                );
                if (relPath != null) {
                  setState(() {
                    _classLogoPath = relPath;
                  });
                }
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF4E9F3D).withOpacity(0.15),
                    backgroundImage: (absoluteLogoPath != null && File(absoluteLogoPath).existsSync())
                        ? FileImage(File(absoluteLogoPath))
                        : null,
                    child: (absoluteLogoPath == null || !File(absoluteLogoPath).existsSync())
                        ? const Icon(Icons.camera_alt, color: Color(0xFF4E9F3D), size: 36)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  const Text('Changer la photo / logo de classe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4E9F3D))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Level Selector Chips
          const Text('Niveau de Maternelle :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['TPS', 'PS', 'MS', 'GS', 'Multi-niveaux'].map((level) {
                final isSelected = _selectedLevel == level;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(level),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4E9F3D),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedLevel = level);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _classNameController,
            decoration: const InputDecoration(labelText: 'Nom de la classe', border: OutlineInputBorder(), prefixIcon: Icon(Icons.class_)),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _schoolNameController,
            decoration: const InputDecoration(labelText: 'Nom de l\'École', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teacherController,
                  decoration: const InputDecoration(labelText: 'Enseignant(e)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _atsemController,
                  decoration: const InputDecoration(labelText: 'ATSEM (optionnel)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.face)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _schoolYearController,
            decoration: const InputDecoration(labelText: 'Année Scolaire', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                provider.updateClassSettings(
                  ClassSettings(
                    name: _classNameController.text.trim(),
                    teacher: _teacherController.text.trim(),
                    atsem: _atsemController.text.trim().isEmpty ? null : _atsemController.text.trim(),
                    schoolName: _schoolNameController.text.trim().isEmpty ? null : _schoolNameController.text.trim(),
                    level: _selectedLevel,
                    schoolYear: _schoolYearController.text.trim(),
                    logoPath: _classLogoPath,
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil de classe enregistré avec succès ! 🎉'), backgroundColor: Color(0xFF4E9F3D)),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer le Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E9F3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── TAB 2 : ESPACES & ATELIERS ───────────────────
  Widget _buildSpacesAndWorkshopsTab(AppStateProvider provider) {
    final spaces = provider.spaces;
    final allAteliers = provider.activityTypes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION ESPACES ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📍 Espaces de la Classe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _openSpaceDialog(context, provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Espace'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Définissez les zones / coins de votre classe.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          // Spaces list
          ...spaces.map((space) {
            final ateliersInSpace = allAteliers.where((a) => a.spaceId == space.id).toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(space.colorHex.replaceFirst('#', '0xff'))),
                  child: const Icon(Icons.space_dashboard, color: Colors.white, size: 20),
                ),
                title: Text(space.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${ateliersInSpace.length} atelier(s)${space.description != null ? ' • ${space.description}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                      onPressed: () => _openSpaceDialog(context, provider, space: space),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer cet espace ?'),
                            content: Text('Cela supprimera aussi les ${ateliersInSpace.length} atelier(s) rattachés.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () {
                                  provider.deleteSpace(space.id);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                children: [
                  // Ateliers in this space
                  ...ateliersInSpace.map((atelier) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(int.parse(atelier.colorHex.replaceFirst('#', '0xff'))),
                      child: const Icon(Icons.palette, size: 14, color: Colors.white),
                    ),
                    title: Text(atelier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (atelier.domaine.isNotEmpty)
                          Text('📚 ${atelier.domaine}', style: const TextStyle(fontSize: 11)),
                        if (atelier.objectifs.isNotEmpty)
                          Text('🎯 ${atelier.objectifs.join(", ")}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onPressed: () => _openActivityTypeDialog(context, provider, activityType: atelier),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => provider.deleteActivityType(atelier.id),
                        ),
                      ],
                    ),
                    isThreeLine: atelier.domaine.isNotEmpty || atelier.objectifs.isNotEmpty,
                  )),
                  // Add atelier button inside expansion
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: () => _openActivityTypeDialog(context, provider, preselectedSpaceId: space.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un atelier dans cet espace'),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (spaces.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Aucun espace défini. Ajoutez votre premier espace !')),
            ),
        ],
      ),
    );
  }

  // ─────────────────── SPACE DIALOG ───────────────────
  void _openSpaceDialog(BuildContext context, AppStateProvider provider, {Space? space}) {
    final nameCtrl = TextEditingController(text: space?.name ?? '');
    final descCtrl = TextEditingController(text: space?.description ?? '');
    String color = space?.colorHex ?? '#4E9F3D';

    final colors = ['#FF7043', '#4E9F3D', '#7E57C2', '#FFA726', '#42A5F5', '#8D6E63', '#E91E63', '#00BCD4', '#673AB7', '#FF5722'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: Text(space == null ? 'Ajouter un Espace' : 'Modifier l\'Espace'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de l\'espace')),
                    const SizedBox(height: 8),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Couleur :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((c) {
                        final isSelected = c == color;
                        return GestureDetector(
                          onTap: () => setSt(() => color = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(int.parse(c.replaceFirst('#', '0xff'))),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: Color(int.parse(c.replaceFirst('#', '0xff'))), blurRadius: 8)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      final newSpace = Space(
                        id: space?.id ?? 'space_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        colorHex: color,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      );
                      provider.addOrUpdateSpace(newSpace);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────── ATELIER DIALOG (AVEC EDUSCOL & SUR-MESURE) ───────────────────
  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider, {ActivityType? activityType, String? preselectedSpaceId}) {
    final nameCtrl = TextEditingController(text: activityType?.name ?? '');
    final descCtrl = TextEditingController(text: activityType?.description ?? '');
    final customDomaineCtrl = TextEditingController();
    final customObjectiveCtrl = TextEditingController();

    String spaceId = preselectedSpaceId ?? activityType?.spaceId ?? (provider.spaces.isNotEmpty ? provider.spaces.first.id : '');
    String color = activityType?.colorHex ?? '#4E9F3D';

    // Domaine selection
    String? selectedDomainId = EduscolData.domains.any((d) => d.title == activityType?.domaine)
        ? EduscolData.domains.firstWhere((d) => d.title == activityType?.domaine).id
        : (activityType?.domaine.isNotEmpty == true ? 'custom' : EduscolData.domains.first.id);

    if (selectedDomainId == 'custom') {
      customDomaineCtrl.text = activityType?.domaine ?? '';
    }

    // Filter by age/level
    String selectedLevelFilter = 'Tous';

    // Objectives set
    final List<String> selectedObjectives = List<String>.from(activityType?.objectifs ?? []);

    final colors = ['#FF7043', '#4E9F3D', '#7E57C2', '#FFA726', '#42A5F5', '#8D6E63', '#E91E63', '#00BCD4', '#673AB7', '#FF5722'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            final availableEduscolObjectives = EduscolData.objectives.where((obj) {
              final matchDomain = obj.domainId == selectedDomainId;
              final matchLevel = selectedLevelFilter == 'Tous' || obj.level == selectedLevelFilter;
              return matchDomain && matchLevel;
            }).toList();

            return AlertDialog(
              title: Text(activityType == null ? 'Ajouter un Atelier' : 'Modifier l\'Atelier'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom de l\'atelier', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: provider.spaces.any((s) => s.id == spaceId) ? spaceId : null,
                        decoration: const InputDecoration(labelText: 'Espace de classe', border: OutlineInputBorder()),
                        items: provider.spaces.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) {
                          if (val != null) setSt(() => spaceId = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Domaine Éduscol Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedDomainId,
                        decoration: const InputDecoration(
                          labelText: '📚 Domaine Éduscol (Cycle 1)',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
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
                            setSt(() => selectedDomainId = val);
                          }
                        },
                      ),

                      if (selectedDomainId == 'custom') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customDomaineCtrl,
                          decoration: const InputDecoration(labelText: 'Nom du domaine personnalisé', border: OutlineInputBorder()),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Filter by Level (Age)
                      if (selectedDomainId != 'custom') ...[
                        Row(
                          children: [
                            const Text('🎯 Tranche d\'âge / Niveau :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['Tous', 'PS', 'MS', 'GS'].map((lvl) {
                                    final isSelected = selectedLevelFilter == lvl;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: ChoiceChip(
                                        label: Text(
                                          lvl == 'PS' ? 'PS (2-4 ans)' : lvl == 'MS' ? 'MS (4-5 ans)' : lvl == 'GS' ? 'GS (5-6 ans)' : 'Tous',
                                          style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF4E9F3D),
                                        onSelected: (sel) {
                                          if (sel) setSt(() => selectedLevelFilter = lvl);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Éduscol Objectives Checkboxes Container
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: availableEduscolObjectives.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Aucun objectif officiel pour ce filtre.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: availableEduscolObjectives.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final obj = availableEduscolObjectives[idx];
                                    final isChecked = selectedObjectives.contains(obj.text);
                                    return CheckboxListTile(
                                      dense: true,
                                      title: Text(obj.text, style: const TextStyle(fontSize: 12)),
                                      subtitle: Text('Niveau : ${obj.level}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      value: isChecked,
                                      activeColor: const Color(0xFF4E9F3D),
                                      onChanged: (val) {
                                        setSt(() {
                                          if (val == true) {
                                            if (!selectedObjectives.contains(obj.text)) {
                                              selectedObjectives.add(obj.text);
                                            }
                                          } else {
                                            selectedObjectives.remove(obj.text);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Selected Objectives Chips
                      const Text('Objectifs retenus pour cet atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      if (selectedObjectives.isEmpty)
                        const Text('Aucun objectif sélectionné.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedObjectives.map((objText) {
                            return Chip(
                              label: Text(objText, style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () {
                                setSt(() {
                                  selectedObjectives.remove(objText);
                                });
                              },
                              backgroundColor: const Color(0xFF4E9F3D).withOpacity(0.15),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),

                      // Add Custom Objective Input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customObjectiveCtrl,
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
                              final txt = customObjectiveCtrl.text.trim();
                              if (txt.isNotEmpty) {
                                setSt(() {
                                  if (!selectedObjectives.contains(txt)) {
                                    selectedObjectives.add(txt);
                                  }
                                  customObjectiveCtrl.clear();
                                });
                              }
                            },
                            icon: const Icon(Icons.add_circle, color: Color(0xFF4E9F3D), size: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description complémentaire', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      const Text('Couleur de l\'atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: colors.map((c) {
                          final isSelected = c == color;
                          return GestureDetector(
                            onTap: () => setSt(() => color = c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(int.parse(c.replaceFirst('#', '0xff'))),
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                boxShadow: isSelected ? [BoxShadow(color: Color(int.parse(c.replaceFirst('#', '0xff'))), blurRadius: 8)] : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      String finalDomaine = '';
                      if (selectedDomainId == 'custom') {
                        finalDomaine = customDomaineCtrl.text.trim();
                      } else if (selectedDomainId != null) {
                        final dom = EduscolData.domains.firstWhere((d) => d.id == selectedDomainId, orElse: () => EduscolData.domains.first);
                        finalDomaine = dom.title;
                      }

                      final newType = ActivityType(
                        id: activityType?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        spaceId: spaceId,
                        colorHex: color,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        domaine: finalDomaine,
                        objectifs: selectedObjectives,
                      );
                      provider.saveActivityType(newType);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Enregistrer l\'Atelier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────── TAB 3 : APPARENCE ───────────────────
  Widget _buildAppearanceTab(AppStateProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌙 Apparence & Thème Visuel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Personnalisez le mode d\'affichage de l\'interface.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('📱 Mode Automatique (Système)'),
                    subtitle: const Text('S\'adapte aux réglages de votre iPad / iPhone.'),
                    value: ThemeMode.system,
                    groupValue: provider.themeMode,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) => provider.setThemeMode(val!),
                  ),
                  const Divider(),
                  RadioListTile<ThemeMode>(
                    title: const Text('☀️ Mode Clair'),
                    subtitle: const Text('Fond lumineux traditionnel.'),
                    value: ThemeMode.light,
                    groupValue: provider.themeMode,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) => provider.setThemeMode(val!),
                  ),
                  const Divider(),
                  RadioListTile<ThemeMode>(
                    title: const Text('🌙 Mode Sombre (Dark Mode)'),
                    subtitle: const Text('Fond sombre reposant pour les yeux et économe en batterie.'),
                    value: ThemeMode.dark,
                    groupValue: provider.themeMode,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) => provider.setThemeMode(val!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── TAB 4 : SECURITE & BACKUP ───────────────────
  Widget _buildSecurityBackupTab(AppStateProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛡️ Sauvegarde & Sécurité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Gérez les sauvegardes globales et les accès.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // Backup Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_upload, color: Color(0xFF4E9F3D)),
                      SizedBox(width: 8),
                      Text('Sauvegarde de la Classe (ZIP/JSON)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Sauvegardez l\'intégralité des données (élèves, activités, photos) dans un fichier archive pour changer d\'appareil.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await provider.exportFullBackup();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur export: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Exporter'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await provider.importFullBackup();
                            if (mounted) {
                              if (res == 'success') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Données restaurées avec succès ! 🎉'), backgroundColor: Color(0xFF4E9F3D)),
                                );
                              } else if (res == 'invalid') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fichier de sauvegarde invalide.'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.upload),
                          label: const Text('Restaurer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selective Reset
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: const Text('Réinitialisation Sélective (RAZ)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              subtitle: const Text('Vider l\'historique d\'activités ou la liste des élèves pour la rentrée.', style: TextStyle(fontSize: 12)),
              onTap: () => _openResetDialog(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  void _openResetDialog(BuildContext context, AppStateProvider provider) {
    bool clearActivities = false;
    bool clearChildren = false;
    bool clearActivityTypes = false;
    bool resetSettings = false;
    bool clearEvaluationStatuses = false;
    bool clearSpaces = false;
    bool clearPhotos = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('Réinitialisation Sélective')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cochez les données à effacer :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('📋 Historique des activités'),
                      subtitle: const Text('Toutes les observations enregistrées'),
                      value: clearActivities,
                      onChanged: (v) => setSt(() => clearActivities = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('👦 Liste des élèves'),
                      subtitle: const Text('Prénoms, groupes, photos de profil'),
                      value: clearChildren,
                      onChanged: (v) => setSt(() => clearChildren = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('🎨 Catalogue des ateliers'),
                      subtitle: const Text('Tous les types d\'ateliers configurés'),
                      value: clearActivityTypes,
                      onChanged: (v) => setSt(() => clearActivityTypes = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('📍 Espaces de classe'),
                      subtitle: const Text('Remettre les espaces par défaut'),
                      value: clearSpaces,
                      onChanged: (v) => setSt(() => clearSpaces = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('📊 Niveaux d\'évaluation'),
                      subtitle: const Text('Remettre les statuts par défaut'),
                      value: clearEvaluationStatuses,
                      onChanged: (v) => setSt(() => clearEvaluationStatuses = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('🏫 Profil de classe'),
                      subtitle: const Text('Nom de classe, enseignant, école, année'),
                      value: resetSettings,
                      onChanged: (v) => setSt(() => resetSettings = v ?? false),
                      activeColor: Colors.red,
                    ),
                    CheckboxListTile(
                      title: const Text('📷 Photos & médias'),
                      subtitle: const Text('Supprimer toutes les photos stockées'),
                      value: clearPhotos,
                      onChanged: (v) => setSt(() => clearPhotos = v ?? false),
                      activeColor: Colors.red,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    provider.resetSelectiveData(
                      clearChildren: clearChildren,
                      clearActivityTypes: clearActivityTypes,
                      clearActivities: clearActivities,
                      resetSettings: resetSettings,
                      clearEvaluationStatuses: clearEvaluationStatuses,
                      clearSpaces: clearSpaces,
                      clearPhotos: clearPhotos,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Données réinitialisées avec succès ✅'), backgroundColor: Colors.red),
                    );
                  },
                  label: const Text('Confirmer la RAZ'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
