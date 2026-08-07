import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    _classNameController = TextEditingController(text: provider.classSettings.name);
    _teacherController = TextEditingController(text: provider.classSettings.teacher);
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
          const Text('Personnalisez 100% de la classe et des ateliers', style: TextStyle(color: Color(0xFF718096))),

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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(act.colorHex.replaceFirst('#', '0xff'))),
                    child: const Icon(Icons.palette, color: Colors.white, size: 18),
                  ),
                  title: Text(act.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(act.category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => provider.deleteActivityType(act.id),
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
              onPressed: () => _confirmReset(context, provider),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                'Réinitialiser toutes les données (RAZ)',
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

  void _confirmReset(BuildContext context, AppStateProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Réinitialisation (RAZ)'),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer TOUTES les données ?\n\n'
            'Cette action supprimera tous les élèves, ateliers et historiques d\'activités de manière définitive.',
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
              onPressed: () {
                provider.resetData();
                Navigator.pop(context);
                
                // Reset text controllers
                setState(() {
                  _classNameController.text = "Classe Nouvelle (RAZ)";
                  _teacherController.text = "";
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Données réinitialisées avec succès !')),
                );
              },
              child: const Text('Confirmer la RAZ'),
            ),
          ],
        );
      },
    );
  }

  void _openActivityTypeDialog(BuildContext context, AppStateProvider provider) {
    final nameController = TextEditingController();
    final catController = TextEditingController(text: 'Créatif');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvel Atelier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de l\'atelier')),
              const SizedBox(height: 10),
              TextField(controller: catController, decoration: const InputDecoration(labelText: 'Catégorie')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                provider.addOrUpdateActivityType(
                  ActivityType(
                    id: 'act_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    category: catController.text.trim(),
                    iconName: 'shapes',
                    colorHex: '#FF7043',
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }
}
