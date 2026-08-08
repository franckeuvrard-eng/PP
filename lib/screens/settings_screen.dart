import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/class_settings.dart';
import '../models/activity_type.dart';

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

  final TextEditingController _newCategoryController = TextEditingController();
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
    _newCategoryController.dispose();
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
            Tab(icon: Icon(Icons.palette), text: 'Ateliers & Packs'),
            Tab(icon: Icon(Icons.brightness_6), text: 'Apparence'),
            Tab(icon: Icon(Icons.security), text: 'Sauvegarde & Sécurité'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClassProfileTab(provider),
          _buildWorkshopsTab(provider),
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

  // ─────────────────── TAB 2 : ATELIERS & PACKS ───────────────────
  Widget _buildWorkshopsTab(AppStateProvider provider) {
    final types = provider.activityTypes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🎨 Catalogue des Ateliers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _openActivityTypeDialog(context, provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E9F3D), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── PACKS CLE EN MAIN ──
          Card(
            color: const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text('Packs d\'Ateliers Clé en Main', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Importez un pack d\'ateliers prédéfinis conformes aux programmes :', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.backpack, size: 16),
                        label: const Text('Pack Rentrée & Autonomie'),
                        onPressed: () => _importPack(context, provider, 'rentree'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.draw, size: 16),
                        label: const Text('Pack Motricité Fine & Graphisme'),
                        onPressed: () => _importPack(context, provider, 'graphisme'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calculate, size: 16),
                        label: const Text('Pack Mathématiques & Logic'),
                        onPressed: () => _importPack(context, provider, 'maths'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── WORKSHOPS LIST ──
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final type = types[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(type.colorHex.replaceFirst('#', '0xff'))),
                  child: const Icon(Icons.palette, color: Colors.white, size: 18),
                ),
                title: Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${type.category} • ${type.description ?? ""}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () => _openActivityTypeDialog(context, provider, activityType: type),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => provider.deleteActivityType(type.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _importPack(BuildContext context, AppStateProvider provider, String packKey) {
    List<ActivityType> pack = [];

    if (packKey == 'rentree') {
      pack = [
        ActivityType(id: 'p_r1', name: 'Rangement des Jeux', category: 'Vie Pratique', iconName: 'inventory', colorHex: '#4E9F3D', description: 'Apprendre à trier et ranger les jeux après le temps libre.'),
        ActivityType(id: 'p_r2', name: 'Lavage des Mains', category: 'Autonomie', iconName: 'clean_hands', colorHex: '#42A5F5', description: 'Autonomie au lavabo avant le repas et après la récréation.'),
        ActivityType(id: 'p_r3', name: 'Habillage & Manteau', category: 'Autonomie', iconName: 'checkroom', colorHex: '#FFA726', description: 'Mettre son manteau et fermer les fermetures éclair.'),
      ];
    } else if (packKey == 'graphisme') {
      pack = [
        ActivityType(id: 'p_g1', name: 'Pâte à Modeler & Colombins', category: 'Motricité Fine', iconName: 'gesture', colorHex: '#E91E63', description: 'Former de petites boules et colombins pour muscler les doigts.'),
        ActivityType(id: 'p_g2', name: 'Découpage aux Ciseaux', category: 'Motricité Fine', iconName: 'content_cut', colorHex: '#9C27B0', description: 'Tenir les ciseaux et découper le long de lignes droites.'),
        ActivityType(id: 'p_g3', name: 'Lignes Verticales & Horizontales', category: 'Graphisme', iconName: 'border_color', colorHex: '#FF9800', description: 'Tracés guidés de haut en bas et de gauche à droite.'),
      ];
    } else if (packKey == 'maths') {
      pack = [
        ActivityType(id: 'p_m1', name: 'Tri par Couleur & Forme', category: 'Mathématiques', iconName: 'category', colorHex: '#3F51B5', description: 'Classer des objets selon la couleur ou la forme géométrique.'),
        ActivityType(id: 'p_m2', name: 'Dénombrement (1 à 3)', category: 'Mathématiques', iconName: 'pin', colorHex: '#009688', description: 'Dénombrer de petites collections d\'objets jusqu\'à 3.'),
        ActivityType(id: 'p_m3', name: 'Algorithme Simple AB-AB', category: 'Logic', iconName: 'alt_route', colorHex: '#673AB7', description: 'Poursuivre une suite logique alternant deux couleurs.'),
      ];
    }

    provider.importActivityTypePack(pack);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pack "${packKey.toUpperCase()}" importé avec succès ! 🎉'), backgroundColor: const Color(0xFF4E9F3D)),
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

  // ─────────────────── TAB 4 : SECURIATION & BACKUP ───────────────────
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

  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider, {ActivityType? activityType}) {
    final nameCtrl = TextEditingController(text: activityType?.name ?? '');
    final descCtrl = TextEditingController(text: activityType?.description ?? '');
    String cat = activityType?.category ?? (provider.categories.isNotEmpty ? provider.categories.first : 'Autre');
    String color = activityType?.colorHex ?? '#4E9F3D';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(activityType == null ? 'Ajouter un Atelier' : 'Modifier l\'Atelier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de l\'atelier')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(labelText: 'Domaine / Catégorie'),
                items: provider.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) cat = val;
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final newType = ActivityType(
                    id: activityType?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    category: cat,
                    iconName: activityType?.iconName ?? 'palette',
                    colorHex: color,
                    description: descCtrl.text.trim(),
                  );
                  provider.saveActivityType(newType);
                  Navigator.pop(context);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _openResetDialog(BuildContext context, AppStateProvider provider) {
    bool clearActivities = false;
    bool clearChildren = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Réinitialisation Sélective'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Effacer tout l\'historique des activités'),
                    value: clearActivities,
                    onChanged: (v) => setSt(() => clearActivities = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Effacer la liste des élèves'),
                    value: clearChildren,
                    onChanged: (v) => setSt(() => clearChildren = v ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    provider.resetSelectiveData(
                      clearChildren: clearChildren,
                      clearActivityTypes: false,
                      clearActivities: clearActivities,
                      resetSettings: false,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Données réinitialisées')));
                  },
                  child: const Text('Confirmer Réinitialisation'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
