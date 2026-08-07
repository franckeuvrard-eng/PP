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

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _classNameController;
  late TextEditingController _teacherController;
  final TextEditingController _newStatusController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    _classNameController = TextEditingController(text: provider.classSettings.name);
    _teacherController = TextEditingController(text: provider.classSettings.teacher);
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _teacherController.dispose();
    _newStatusController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Centre de Paramétrage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Personnalisez l\'application par sections', style: TextStyle(color: Color(0xFF718096))),
          const SizedBox(height: 16),

          // ── SECTION 1 : Infos de classe ──
          _buildSection(
            icon: Icons.school,
            title: '🏫  Informations de la classe',
            color: const Color(0xFF4E9F3D),
            initiallyExpanded: false,
            children: [
              TextField(
                controller: _classNameController,
                decoration: const InputDecoration(labelText: 'Nom de la classe', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _teacherController,
                decoration: const InputDecoration(labelText: 'Enseignante', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  provider.updateClassSettings(
                    ClassSettings(
                      name: _classNameController.text.trim(),
                      teacher: _teacherController.text.trim(),
                      level: provider.classSettings.level,
                      schoolYear: provider.classSettings.schoolYear,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paramètres enregistrés')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── SECTION 2 : Statuts d'évaluation ──
          _buildSection(
            icon: Icons.star_border,
            title: '📊  Statuts d\'évaluation',
            color: const Color(0xFFFF7043),
            initiallyExpanded: false,
            children: [
              const Text('Personnalisez les statuts de suivi des activités',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
              const SizedBox(height: 10),
              ...provider.evaluationStatuses.map((status) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => _confirmDeleteStatus(context, provider, status),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newStatusController,
                      decoration: const InputDecoration(
                        hintText: 'Nouveau statut (ex: Acquis 🟢)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () {
                      final text = _newStatusController.text.trim();
                      if (text.isNotEmpty) {
                        final updated = List<String>.from(provider.evaluationStatuses)..add(text);
                        provider.setEvaluationStatuses(updated);
                        _newStatusController.clear();
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── SECTION 3 : Catégories d'ateliers ──
          _buildSection(
            icon: Icons.category,
            title: '🎨  Catégories d\'ateliers',
            color: const Color(0xFF7E57C2),
            initiallyExpanded: false,
            children: [
              const Text('Personnalisez les catégories d\'activités proposées',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
              const SizedBox(height: 10),
              ...provider.categories.map((category) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => _confirmDeleteCategory(context, provider, category),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        hintText: 'Nouvelle catégorie (ex: Sciences)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () {
                      final text = _newCategoryController.text.trim();
                      if (text.isNotEmpty) {
                        final updated = List<String>.from(provider.categories)..add(text);
                        provider.setCategories(updated);
                        _newCategoryController.clear();
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── SECTION 4 : Ateliers & Activités ──
          _buildSection(
            icon: Icons.palette,
            title: '🎯  Ateliers & Activités',
            color: const Color(0xFFFFA726),
            initiallyExpanded: false,
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFFA726)),
              onPressed: () => _openActivityTypeDialog(context, provider),
              tooltip: 'Ajouter un atelier',
            ),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.activityTypes.length,
                itemBuilder: (context, index) {
                  final act = provider.activityTypes[index];
                  final absolutePath = provider.getAbsolutePath(act.imagePath);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => _openActivityTypeDialog(context, provider, act: act),
                      leading: absolutePath != null && File(absolutePath).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(absolutePath), width: 36, height: 36, fit: BoxFit.cover),
                            )
                          : CircleAvatar(
                              backgroundColor: Color(int.parse(act.colorHex.replaceFirst('#', '0xff'))),
                              radius: 18,
                              child: const Icon(Icons.palette, color: Colors.white, size: 16),
                            ),
                      title: Text(act.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(act.category),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteActivityType(context, provider, act),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── SECTION 5 : Sauvegarde / Import / RAZ ──
          _buildSection(
            icon: Icons.backup,
            title: '🗄️  Sauvegarde & Données',
            color: const Color(0xFF42A5F5),
            initiallyExpanded: false,
            children: [
              const Text(
                'Exportez une sauvegarde complète incluant toutes vos données et photos, ou restaurez depuis un fichier ZIP.',
                style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await provider.exportFullBackup();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur export : $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Exporter la sauvegarde complète'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await provider.importFullBackup();
                    if (!context.mounted) return;
                    switch (result) {
                      case 'success':
                        setState(() {
                          _classNameController.text = provider.classSettings.name;
                          _teacherController.text = provider.classSettings.teacher;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sauvegarde restaurée avec succès !'),
                            backgroundColor: Color(0xFF4E9F3D),
                          ),
                        );
                        break;
                      case 'cancelled':
                        break;
                      case 'invalid':
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fichier invalide : backup.json manquant.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        break;
                      default:
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erreur lors de l\'import.'), backgroundColor: Colors.red),
                        );
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Importer une sauvegarde (.zip)'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                    foregroundColor: const Color(0xFF42A5F5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const Divider(height: 30),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSelectiveReset(context, provider),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    'Réinitialisation des données (RAZ)',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── Generic collapsible section builder ───
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
    Widget? trailing,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          radius: 18,
          child: Icon(icon, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: trailing ??
            Icon(Icons.keyboard_arrow_down, color: color),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  // ─────────────────── DIALOGS ───────────────────

  void _confirmDeleteStatus(BuildContext context, AppStateProvider provider, String status) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer ce statut ?'),
          content: Text('Voulez-vous vraiment retirer le statut « $status » ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final updated = List<String>.from(provider.evaluationStatuses)..remove(status);
                provider.setEvaluationStatuses(updated);
                Navigator.pop(context);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, AppStateProvider provider, String category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer cette catégorie ?'),
          content: Text('Voulez-vous vraiment retirer la catégorie « $category » ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final updated = List<String>.from(provider.categories)..remove(category);
                provider.setCategories(updated);
                Navigator.pop(context);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteActivityType(BuildContext context, AppStateProvider provider, ActivityType act) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Confirmer la suppression'),
            ],
          ),
          content: Text('Voulez-vous vraiment supprimer l\'atelier « ${act.name} » ? Cette action est irréversible.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                provider.deleteActivityType(act.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Atelier « ${act.name} » supprimé.')),
                );
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void _confirmSelectiveReset(BuildContext context, AppStateProvider provider) {
    bool clearChildren = true;
    bool clearActivityTypes = true;
    bool clearActivities = true;
    bool resetSettings = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Réinitialisation Sélective'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sélectionnez les catégories de données que vous souhaitez supprimer définitivement :',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Liste des Élèves', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Efface tous les enfants et leurs photos', style: TextStyle(fontSize: 11)),
                      value: clearChildren,
                      onChanged: (val) => setDialogState(() => clearChildren = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Ateliers & Activités', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Efface les fiches d\'ateliers créées', style: TextStyle(fontSize: 11)),
                      value: clearActivityTypes,
                      onChanged: (val) => setDialogState(() => clearActivityTypes = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Historique des activités', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Efface le journal des scans et photos d\'activité', style: TextStyle(fontSize: 11)),
                      value: clearActivities,
                      onChanged: (val) => setDialogState(() => clearActivities = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Paramètres Classe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Réinitialise le nom de la classe et de l\'enseignante', style: TextStyle(fontSize: 11)),
                      value: resetSettings,
                      onChanged: (val) => setDialogState(() => resetSettings = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: (!clearChildren && !clearActivityTypes && !clearActivities && !resetSettings)
                      ? null
                      : () {
                          provider.resetSelectiveData(
                            clearChildren: clearChildren,
                            clearActivityTypes: clearActivityTypes,
                            clearActivities: clearActivities,
                            resetSettings: resetSettings,
                          );
                          Navigator.pop(context);
                          if (resetSettings) {
                            setState(() {
                              _classNameController.text = 'Classe Nouvelle (RAZ)';
                              _teacherController.text = '';
                            });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Données réinitialisées selon vos choix.')),
                          );
                        },
                  child: const Text('Confirmer la suppression'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider, {ActivityType? act}) {
    showDialog(
      context: context,
      builder: (context) => _ActivityTypeFormDialog(provider: provider, act: act),
    );
  }
}

// ─── Proper StatefulWidget for activity type dialog ───
// Using a full StatefulWidget instead of StatefulBuilder ensures that
// setState() always works after iOS camera dismissal (full-screen takeover).
class _ActivityTypeFormDialog extends StatefulWidget {
  final AppStateProvider provider;
  final ActivityType? act;

  const _ActivityTypeFormDialog({required this.provider, this.act});

  @override
  State<_ActivityTypeFormDialog> createState() => _ActivityTypeFormDialogState();
}

class _ActivityTypeFormDialogState extends State<_ActivityTypeFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _catController;
  late final TextEditingController _descController;
  String? _selectedImagePath;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final act = widget.act;
    final provider = widget.provider;
    _nameController = TextEditingController(text: act?.name ?? '');
    _catController = TextEditingController(text: act?.category ?? '');
    _descController = TextEditingController(text: act?.description ?? '');
    _selectedImagePath = provider.getAbsolutePath(act?.imagePath);

    // Resolve default category
    if (act != null && provider.categories.contains(act.category)) {
      _selectedCategory = act.category;
    } else if (provider.categories.isNotEmpty) {
      _selectedCategory = provider.categories.first;
    } else {
      _selectedCategory = 'Général';
    }
    _catController.text = _selectedCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _catController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final relPath = await widget.provider.saveXFileToDocs(image, 'workshops');
      if (mounted) {
        setState(() {
          _selectedImagePath = widget.provider.getAbsolutePath(relPath);
        });
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      final relPath = await widget.provider.saveXFileToDocs(image, 'workshops');
      if (mounted) {
        setState(() {
          _selectedImagePath = widget.provider.getAbsolutePath(relPath);
        });
      }
    }
  }

  bool get _hasValidImage {
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) return false;
    return File(_selectedImagePath!.replaceFirst('file://', '')).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.act;
    final provider = widget.provider;

    return AlertDialog(
      title: Text(act == null ? 'Nouvel Atelier' : 'Modifier l\'Atelier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo preview + picker
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _hasValidImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_selectedImagePath!.replaceFirst('file://', '')),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.photo_camera, size: 14),
                    label: const Text('Prendre une photo', style: TextStyle(fontSize: 12)),
                    onPressed: _pickFromCamera,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom de l\'atelier *'),
            ),
            const SizedBox(height: 12),
            if (provider.categories.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                items: provider.categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                      _catController.text = val;
                    });
                  }
                },
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description / Instructions'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.trim().isEmpty) return;

            String? relativeImagePath = act?.imagePath;
            if (_selectedImagePath != null &&
                _selectedImagePath != provider.getAbsolutePath(act?.imagePath)) {
              if (_selectedImagePath!.contains('workshops/')) {
                final filename = _selectedImagePath!.split('workshops/').last;
                relativeImagePath = 'workshops/$filename';
              } else {
                relativeImagePath = await provider.saveImageToDocs(_selectedImagePath!, 'workshops');
              }
            }

            final newAct = ActivityType(
              id: act?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameController.text.trim(),
              category: _catController.text.trim(),
              description: _descController.text.trim(),
              imagePath: relativeImagePath,
              iconName: act?.iconName ?? 'palette',
              colorHex: act?.colorHex ?? '#FF7043',
            );
            provider.addOrUpdateActivityType(newAct);
            if (mounted) {
              Navigator.pop(context);
            }
          },
          child: Text(act == null ? 'Créer' : 'Enregistrer'),
        ),
      ],
    );
  }
}
