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
          const Text('Centre de Paramétrage UI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Personnalisez les ateliers, catégories, statuts, et l\'école', style: TextStyle(color: Color(0xFF718096))),

          const SizedBox(height: 20),

          // Class Settings Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informations Classe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
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
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Evaluation Status Settings Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Niveaux d\'Évaluation (Statuts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Personnalisez les statuts de suivi des activités', style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                  const SizedBox(height: 12),
                  
                  // Statuses List
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

                  const SizedBox(height: 12),

                  // Add Status form
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
                          backgroundColor: const Color(0xFF4E9F3D),
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
            ),
          ),

          const SizedBox(height: 16),

          // Workshop Categories Settings Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catégories d\'Ateliers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Personnalisez les catégories d\'activités proposées', style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                  const SizedBox(height: 12),
                  
                  // Categories List
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

                  const SizedBox(height: 12),

                  // Add Category form
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
                          backgroundColor: const Color(0xFF4E9F3D),
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
            ),
          ),

          const SizedBox(height: 16),

          // Activity Types Config Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ateliers & Activités', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4E9F3D)),
                onPressed: () => _openActivityTypeDialog(context, provider),
              ),
            ],
          ),

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
          const SizedBox(height: 30),

          // Reset Database Button
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStatus(BuildContext context, AppStateProvider provider, String status) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer ce statut ?'),
          content: Text('Voulez-vous vraiment retirer le statut « $status » ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
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
                      'Sélectionnez les catégories de données que vous souhaitez supprimer définitivement de l\'appareil :',
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
                              _classNameController.text = "Classe Nouvelle (RAZ)";
                              _teacherController.text = "";
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
    final nameController = TextEditingController(text: act?.name ?? '');
    final catController = TextEditingController(text: act?.category ?? 'Général');
    final descController = TextEditingController(text: act?.description ?? '');
    String? selectedImagePath = provider.getAbsolutePath(act?.imagePath);

    // Default category dropdown selection
    String defaultCat = provider.categories.first;
    if (act != null && provider.categories.contains(act.category)) {
      defaultCat = act.category;
    } else if (provider.categories.contains(catController.text)) {
      defaultCat = catController.text;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(act == null ? 'Nouvel Atelier' : 'Modifier l\'Atelier'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview Photo
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                setDialogState(() {
                                  selectedImagePath = image.path;
                                });
                              }
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: (selectedImagePath != null && selectedImagePath!.isNotEmpty && File(selectedImagePath!).existsSync())
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(File(selectedImagePath!), fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            icon: const Icon(Icons.photo_camera, size: 14),
                            label: const Text('Prendre une photo', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.camera);
                              if (image != null) {
                                setDialogState(() {
                                  selectedImagePath = image.path;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de l\'atelier *')),
                    const SizedBox(height: 12),

                    // Category dropdown (ComboBox) instead of text field
                    DropdownButtonFormField<String>(
                      value: defaultCat,
                      decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                      items: provider.categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          catController.text = val;
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description / Instructions'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    // Handle persistent workshop image copy
                    String? relativeImagePath = act?.imagePath;
                    if (selectedImagePath != null && selectedImagePath != provider.getAbsolutePath(act?.imagePath)) {
                      relativeImagePath = await provider.saveImageToDocs(selectedImagePath!, 'workshops');
                    }

                    final newAct = ActivityType(
                      id: act?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text.trim(),
                      category: catController.text.trim(),
                      description: descController.text.trim(),
                      imagePath: relativeImagePath,
                      iconName: act?.iconName ?? 'palette',
                      colorHex: act?.colorHex ?? '#FF7043',
                    );
                    provider.addOrUpdateActivityType(newAct);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(act == null ? 'Créer' : 'Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
