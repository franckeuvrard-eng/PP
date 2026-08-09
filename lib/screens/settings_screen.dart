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
                          Text('🏁 ${atelier.objectifs.length} objectif(s) associé(s)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (atelier.isObligatory)
                          const Text('⭐ Atelier Obligatoire', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
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

  // ─────────────────── ATELIER EDIT SCREEN (PLEIN ÉCRAN MOBILE) ───────────────────
  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider, {ActivityType? activityType, String? preselectedSpaceId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AtelierEditScreen(
          activityType: activityType,
          preselectedSpaceId: preselectedSpaceId,
        ),
      ),
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

// ─────────────────── ATELIER EDIT SCREEN (PAGE PLEIN ÉCRAN ACCESSIBLE MOBILE) ───────────────────
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

    _selectedDomainId = EduscolData.domains.any((d) => d.title == act?.domaine)
        ? EduscolData.domains.firstWhere((d) => d.title == act?.domaine).id
        : (act?.domaine.isNotEmpty == true ? 'custom' : 'none');

    if (_selectedDomainId == 'custom') {
      _customDomaineCtrl.text = act?.domaine ?? '';
    }

    _selectedLevelFilter = 'Tous';
    _selectedObjectives = List<String>.from(act?.objectifs ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customDomaineCtrl.dispose();
    _customObjectiveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final availableEduscolObjectives = EduscolData.objectives.where((obj) {
      final matchDomain = obj.domainId == _selectedDomainId;
      final matchLevel = _selectedLevelFilter == 'Tous' || obj.level == _selectedLevelFilter;
      return matchDomain && matchLevel;
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
                        'Cochez si cet atelier doit être réalisé par l\'ensemble des élèves de la classe.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _isObligatory,
                      activeColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setState(() => _isObligatory = val),
                    ),
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
                      value: _selectedDomainId,
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
                      Row(
                        children: [
                          const Text('🎯 Tranche d\'âge / Niveau :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Tous', 'PS', 'MS', 'GS'].map((lvl) {
                                  final isSelected = _selectedLevelFilter == lvl;
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
                                        if (sel) setState(() => _selectedLevelFilter = lvl);
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

                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: availableEduscolObjectives.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Aucun objectif officiel disponible pour ce filtre.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: availableEduscolObjectives.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final obj = availableEduscolObjectives[idx];
                                  final isChecked = _selectedObjectives.contains(obj.text);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(obj.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    subtitle: Text('Niveau Éduscol : ${obj.level}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAtelier,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer l\'Atelier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    if (_selectedDomainId == 'custom') {
      finalDomaine = _customDomaineCtrl.text.trim();
    } else if (_selectedDomainId != null) {
      final dom = EduscolData.domains.firstWhere((d) => d.id == _selectedDomainId, orElse: () => EduscolData.domains.first);
      finalDomaine = dom.title;
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final newType = ActivityType(
      id: widget.activityType?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      spaceId: _spaceId,
      colorHex: _color,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      domaine: finalDomaine,
      objectifs: _selectedObjectives,
      isObligatory: _isObligatory,
    );

    provider.saveActivityType(newType);
    Navigator.pop(context);
  }
}
