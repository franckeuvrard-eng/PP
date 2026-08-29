import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/class_settings.dart';
import '../models/evaluation_status.dart';
import '../services/children_import_service.dart';
import '../utils/color_utils.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/school_year_card.dart';
import 'privacy_policy_screen.dart';
import 'referentials_manager_screen.dart';
import 'spaces_workshops_tab.dart';

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
          labelColor: kAccessibleGreenText,
          unselectedLabelColor: kMutedTextColor,
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
          const SpacesWorkshopsTab(),
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
          const Text('Ces informations seront affichées sur les livrets et exports PDF.', style: TextStyle(fontSize: 12, color: kMutedTextColor)),
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
                  const Text('Changer la photo / logo de classe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccessibleGreenText)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionsCard(context, provider),
          const SizedBox(height: 16),

          _buildStatusesCard(context, provider),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.checklist_rtl, color: Color(0xFF4E9F3D)),
              title: const Text('Référentiels personnalisés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(
                provider.referentials.isEmpty
                    ? 'Ceintures de couleur, Montessori... créez vos propres suivis.'
                    : '${provider.referentials.length} référentiel(s) défini(s)',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReferentialsManagerScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFF4E9F3D)),
              title: const Text('Importer des élèves (Excel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: const Text('Modèle vierge à remplir, puis import en masse.', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openImportExcelSheet(context, provider),
            ),
          ),
          const SizedBox(height: 16),

          // Level Selector Chips
          const Text('Niveau de Maternelle :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['TPS', 'PS', 'MS', 'GS', 'Multi-niveaux'].map((level) {
              final isSelected = _selectedLevel == level;
              return ChoiceChip(
                label: Text(level),
                selected: isSelected,
                selectedColor: const Color(0xFF4E9F3D),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (sel) {
                  if (sel) setState(() => _selectedLevel = level);
                },
              );
            }).toList(),
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

  void _openImportExcelSheet(BuildContext context, AppStateProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Importer des élèves depuis Excel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Télécharger le modèle Excel'),
              subtitle: const Text('Une matrice vierge à remplir hors de l\'application.'),
              onTap: () {
                Navigator.pop(sheetContext);
                ChildrenImportService.shareTemplate(context: context, provider: provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importer un fichier rempli'),
              subtitle: const Text('Crée un élève par ligne du fichier.'),
              onTap: () {
                Navigator.pop(sheetContext);
                ChildrenImportService.pickAndImport(context: context, provider: provider);
              },
            ),
            const SizedBox(height: 8),
          ],
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
          const Text('Personnalisez le mode d\'affichage de l\'interface.', style: TextStyle(fontSize: 12, color: kMutedTextColor)),
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

  /// Gestion des sections de la classe.
  ///
  /// Elles alimentent la fiche eleve et le ciblage des ateliers obligatoires :
  /// les definir ici evite les sections fantomes nees d'une faute de frappe.
  Widget _buildSectionsCard(BuildContext context, AppStateProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.groups, color: Color(0xFF4E9F3D)),
                SizedBox(width: 8),
                Text('Sections / Groupes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Utilisées sur les fiches élèves et pour cibler les ateliers obligatoires.',
              style: TextStyle(fontSize: 12, color: kMutedTextColor),
            ),
            const SizedBox(height: 10),
            if (provider.sections.isEmpty)
              const Text('Aucune section définie.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: kMutedTextColor)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.sections.map((section) {
                final count = provider.childCountInSection(section);
                return InputChip(
                  label: Text('$section  ($count)', style: const TextStyle(fontSize: 13)),
                  onPressed: () => _renameSection(context, provider, section),
                  onDeleted: () => _deleteSection(context, provider, section, count),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addSection(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une section'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gestion des niveaux d'évaluation.
  ///
  /// Renommer est sans danger : les observations référencent un identifiant
  /// stable, pas le libellé. La couleur est portée par le niveau, ce qui évite
  /// les emojis dans les intitulés — ils ne sont pas imprimables en PDF.
  Widget _buildStatusesCard(BuildContext context, AppStateProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rule, color: Color(0xFF4E9F3D)),
                SizedBox(width: 8),
                Text('Niveaux d\'évaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Proposés lors de chaque observation. Les renommer ne modifie pas '
              'les évaluations déjà enregistrées.',
              style: TextStyle(fontSize: 12, color: kMutedTextColor),
            ),
            const SizedBox(height: 8),
            ...provider.evaluationStatuses.map((status) {
              final couleur = hexToColor(status.colorHex);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                ),
                title: Text(status.label, style: const TextStyle(fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                      tooltip: 'Renommer',
                      onPressed: () => _editStatus(context, provider, status),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Supprimer',
                      onPressed: () => _deleteStatus(context, provider, status),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => _editStatus(context, provider, null),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un niveau'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editStatus(
      BuildContext context, AppStateProvider provider, EvaluationStatus? status) async {
    final ctrl = TextEditingController(text: status?.label ?? '');
    var color = status?.colorHex ?? '#1976D2';
    const palette = ['#D32F2F', '#F9A825', '#388E3C', '#1976D2', '#7B1FA2', '#00838F', '#EF6C00'];

    final result = await showDialog<EvaluationStatus>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(status == null ? 'Nouveau niveau' : 'Modifier le niveau'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Intitulé',
                  hintText: 'Acquis, En cours, À revoir...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Couleur :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              ColorSwatchPicker(
                selectedHex: color,
                palette: palette,
                onChanged: (c) => setSt(() => color = c),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final label = ctrl.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(
                  ctx,
                  status?.copyWith(label: label, colorHex: color) ??
                      EvaluationStatus(
                        id: 'statut_${DateTime.now().millisecondsSinceEpoch}',
                        label: label,
                        colorHex: color,
                      ),
                );
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (result == null) return;

    final updated = List<EvaluationStatus>.from(provider.evaluationStatuses);
    final index = updated.indexWhere((s) => s.id == result.id);
    if (index >= 0) {
      updated[index] = result;
    } else {
      updated.add(result);
    }
    provider.setEvaluationStatuses(updated);
  }

  Future<void> _deleteStatus(
      BuildContext context, AppStateProvider provider, EvaluationStatus status) async {
    final used = provider.activities.where((a) => a.evaluationStatusId == status.id).length;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${status.label} » ?'),
        content: Text(
          used == 0
              ? 'Ce niveau n\'est utilisé par aucune observation.'
              : '$used observation(s) portent ce niveau. Elles le conserveront, '
                  'mais il ne sera plus proposé à la saisie.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    provider.setEvaluationStatuses(
        provider.evaluationStatuses.where((s) => s.id != status.id).toList());
  }

  Future<void> _addSection(BuildContext context, AppStateProvider provider) async {
    final name = await _askSectionName(context, 'Nouvelle section', '');
    if (name == null || name.isEmpty) return;
    provider.setSections([...provider.sections, name]);
  }

  Future<void> _renameSection(
      BuildContext context, AppStateProvider provider, String section) async {
    final name = await _askSectionName(context, 'Renommer la section', section);
    if (name == null || name.isEmpty || name == section) return;
    // Le renommage est repercute sur les eleves et les ateliers concernes.
    provider.renameSection(section, name);
  }

  Future<void> _deleteSection(BuildContext context, AppStateProvider provider,
      String section, int childCount) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « $section » ?'),
        content: Text(
          childCount == 0
              ? 'Aucun élève n\'est rattaché à cette section.'
              : '$childCount élève(s) y sont rattaché(s). Leur fiche conservera '
                  'la mention actuelle, mais la section ne sera plus proposée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    provider.setSections(provider.sections.where((s) => s != section).toList());
  }

  Future<String?> _askSectionName(BuildContext context, String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom de la section',
            hintText: 'Petite Section, Groupe Rouge...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _showAutoBackups(BuildContext context, AppStateProvider provider) async {
    final backups = await provider.listAutoBackups();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sauvegardes automatiques'),
        content: SizedBox(
          width: double.maxFinite,
          child: backups.isEmpty
              ? const Text(
                  'Aucune sauvegarde automatique pour le moment. La première sera '
                  'créée au prochain démarrage, dès que la classe contient des données.',
                  style: TextStyle(fontSize: 13),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: backups.map((file) {
                    final stamp = file.path.split(RegExp(r'[/\\]')).last
                        .replaceFirst('auto_', '')
                        .replaceFirst('.json', '');
                    final sizeKo = (file.lengthSync() / 1024).toStringAsFixed(0);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(stamp.replaceAll('T', ' à ').replaceAll('-', '/'),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('$sizeKo Ko', style: const TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () async {
                          final confirme = await showDialog<bool>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restaurer cette sauvegarde ?'),
                              content: const Text(
                                  'Toutes les données actuelles seront remplacées. '
                                  'Les photos ne sont pas concernées.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Restaurer'),
                                ),
                              ],
                            ),
                          );
                          if (confirme != true) return;
                          final ok = await provider.restoreAutoBackup(file);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Sauvegarde restaurée.' : 'Échec de la restauration.'),
                              backgroundColor: ok ? const Color(0xFF4E9F3D) : Colors.red,
                            ),
                          );
                        },
                        child: const Text('Restaurer'),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
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
          const Text('Gérez les sauvegardes globales et les accès.', style: TextStyle(fontSize: 12, color: kMutedTextColor)),
          const SizedBox(height: 16),

          // Verrouillage a l'ouverture
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fingerprint, color: Color(0xFF4E9F3D)),
                      SizedBox(width: 8),
                      Text('Verrouillage de l\'application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Demander Face ID / code à l\'ouverture',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      provider.biometricLockEnabled
                          ? 'L\'espace enseignant est protégé au démarrage.'
                          : 'L\'application s\'ouvre directement, sans authentification.',
                      style: const TextStyle(fontSize: 12, color: kMutedTextColor),
                    ),
                    value: provider.biometricLockEnabled,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) => provider.setBiometricLockEnabled(val),
                  ),
                  if (!provider.biometricLockEnabled)
                    const Text(
                      'Attention : les données des élèves deviennent accessibles à toute personne ayant l\'appareil en main.',
                      style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  const Text(
                    'La modification prend effet au prochain démarrage de l\'application.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: kMutedTextColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sauvegardes automatiques
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_toggle_off, color: Color(0xFF4E9F3D)),
                      SizedBox(width: 8),
                      Text('Sauvegardes automatiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'L\'application enregistre seule vos données une fois par jour et '
                    'conserve les 5 dernières. Les photos n\'y sont pas incluses : '
                    'seul l\'export ZIP ci-dessous est une sauvegarde complète.',
                    style: TextStyle(fontSize: 12, color: kMutedTextColor),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showAutoBackups(context, provider),
                    icon: const Icon(Icons.restore),
                    label: const Text('Voir et restaurer'),
                  ),
                ],
              ),
            ),
          ),
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

          // Fin d'annee scolaire : archive puis repart a vide
          SchoolYearCard(provider: provider),
          const SizedBox(height: 16),

          // Rappel local des eleves non evalues
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: Color(0xFF4E9F3D)),
                      SizedBox(width: 8),
                      Text('Rappel élèves non évalués', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      provider.reminderEnabled
                          ? 'Rappel actif à ${provider.reminderHour.toString().padLeft(2, '0')}h${provider.reminderMinute.toString().padLeft(2, '0')}'
                          : 'Notification désactivée',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Une notification locale liste les élèves sans observation, si besoin.',
                      style: TextStyle(fontSize: 12, color: kMutedTextColor),
                    ),
                    value: provider.reminderEnabled,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) async {
                      final ok = await provider.setReminderEnabled(val);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Autorisation refusée : activez les notifications dans Réglages iOS.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  if (provider.reminderEnabled)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Changer l\'heure du rappel'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: provider.reminderHour, minute: provider.reminderMinute),
                            helpText: 'Heure du rappel',
                          );
                          if (picked != null) {
                            provider.setReminderTime(picked.hour, picked.minute);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confidentialite / RGPD
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.privacy_tip, color: Color(0xFF4E9F3D)),
              title: const Text('Politique de confidentialité (RGPD)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: const Text('Données collectées, stockage local, droits des familles.', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
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
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await provider.resetSelectiveData(
                      clearChildren: clearChildren,
                      clearActivityTypes: clearActivityTypes,
                      clearActivities: clearActivities,
                      resetSettings: resetSettings,
                      clearEvaluationStatuses: clearEvaluationStatuses,
                      clearSpaces: clearSpaces,
                      clearPhotos: clearPhotos,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Données réinitialisées avec succès ✅'
                            : 'Échec de la réinitialisation : rien n\'a été modifié ❌'),
                        backgroundColor: success ? Colors.red : Colors.orange,
                      ),
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
