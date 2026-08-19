import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/class_settings.dart';
import '../models/activity_type.dart';
import '../models/space.dart';
import '../models/evaluation_status.dart';
import '../models/school_year_archive.dart';
import '../data/eduscol_data.dart';
import '../services/children_import_service.dart';
import '../utils/app_icons.dart';
import 'atelier_detail_screen.dart';
import 'privacy_policy_screen.dart';
import 'referentials_manager_screen.dart';

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
                  child: Icon(iconForName(space.iconName, fallback: Icons.space_dashboard),
                      color: Colors.white, size: 20),
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
                  // Ateliers in this space : glisser-deposer si l'espace impose
                  // un ordre de progression, sinon liste condensee simple.
                  if (space.isProgression)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        final ordered = provider.ateliersInSpaceOrdered(space.id).map((a) => a.id).toList();
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = ordered.removeAt(oldIndex);
                        ordered.insert(newIndex, id);
                        provider.reorderAteliersInSpace(space.id, ordered);
                      },
                      children: [
                        for (final entry in provider.ateliersInSpaceOrdered(space.id).asMap().entries)
                          _buildAtelierTile(context, provider, entry.value,
                              key: ValueKey(entry.value.id), dragIndex: entry.key),
                      ],
                    )
                  else
                    ...ateliersInSpace.map((atelier) => _buildAtelierTile(context, provider, atelier)),
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

  /// Ligne condensee d'un atelier : le detail (domaine, objectifs, photos,
  /// obligatoire) est dans AtelierDetailScreen, a un tap. [dragIndex] non nul
  /// affiche une poignee de glisser-deposer au lieu du chevron (mode
  /// progression) ; le tap reste dedie a l'ouverture du detail dans les deux cas.
  Widget _buildAtelierTile(
    BuildContext context,
    AppStateProvider provider,
    ActivityType atelier, {
    Key? key,
    int? dragIndex,
  }) {
    return ListTile(
      key: key,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Color(int.parse(atelier.colorHex.replaceFirst('#', '0xff'))),
        child: Icon(iconForName(atelier.iconName, fallback: Icons.palette), size: 14, color: Colors.white),
      ),
      title: Text(atelier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: atelier.domaine.isEmpty && atelier.objectifs.isEmpty
          ? null
          : Text(
              [
                if (atelier.domaine.isNotEmpty) '📚 ${atelier.domaine}',
                if (atelier.objectifs.isNotEmpty) '🏁 ${atelier.objectifs.length} objectif(s)',
              ].join('  •  '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
      trailing: dragIndex != null
          ? ReorderableDragStartListener(
              index: dragIndex,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AtelierDetailScreen(atelier: atelier)),
      ),
    );
  }

  // ─────────────────── SPACE DIALOG ───────────────────
  void _openSpaceDialog(BuildContext context, AppStateProvider provider, {Space? space}) {
    final nameCtrl = TextEditingController(text: space?.name ?? '');
    final descCtrl = TextEditingController(text: space?.description ?? '');
    String color = space?.colorHex ?? '#4E9F3D';
    String? iconName = space?.iconName;
    bool isProgression = space?.isProgression ?? false;
    String? progressionMinStatusId = space?.progressionMinStatusId ??
        (provider.evaluationStatuses.isNotEmpty ? provider.evaluationStatuses.last.id : null);

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
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Icône :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.replaceFirst('#', '0xff'))).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconForName(iconName, fallback: Icons.space_dashboard),
                            color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showAppIconPicker(context, iconName);
                              if (picked != null) {
                                setSt(() => iconName = picked.isEmpty ? null : picked);
                              }
                            },
                            icon: const Icon(Icons.emoji_symbols),
                            label: Text(iconName == null ? 'Choisir' : iconName!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mode progression (ordre imposé)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text(
                        "Les ateliers de cet espace doivent être faits dans l'ordre : un atelier reste verrouillé tant que les précédents n'ont pas atteint le statut minimum choisi.",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isProgression,
                      activeColor: const Color(0xFF4E9F3D),
                      onChanged: (val) => setSt(() => isProgression = val),
                    ),
                    if (isProgression && provider.evaluationStatuses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "⚠️ Aucun niveau d'évaluation n'existe : aucun atelier ne pourra jamais être débloqué. Créez-en au moins un dans Réglages.",
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isProgression && provider.evaluationStatuses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: provider.evaluationStatuses.any((s) => s.id == progressionMinStatusId)
                            ? progressionMinStatusId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Statut minimum pour débloquer le suivant',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: provider.evaluationStatuses.map((s) {
                          return DropdownMenuItem(value: s.id, child: Text(s.label));
                        }).toList(),
                        onChanged: (val) => setSt(() => progressionMinStatusId = val),
                      ),
                    ],
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
                        iconName: iconName,
                        isProgression: isProgression,
                        progressionMinStatusId: isProgression ? progressionMinStatusId : space?.progressionMinStatusId,
                      );
                      provider.addOrUpdateSpace(newSpace);
                      if (isProgression) {
                        provider.setSpaceProgression(newSpace.id, true, minStatusId: progressionMinStatusId);
                      }
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
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (provider.sections.isEmpty)
              const Text('Aucune section définie.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
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
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...provider.evaluationStatuses.map((status) {
              final couleur = Color(int.parse(status.colorHex.replaceFirst('#', '0xff')));
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: palette.map((c) {
                  final selected = c == color;
                  return GestureDetector(
                    onTap: () => setSt(() => color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', '0xff'))),
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
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

  Future<String?> _askSectionName(BuildContext context, String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
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
          const Text('Gérez les sauvegardes globales et les accès.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
          _SchoolYearCard(provider: provider),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    const SizedBox(height: 16),

                    const Text('Icône de l\'atelier :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(int.parse(_color.replaceFirst('#', '0xff'))).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconForName(_iconName, fallback: Icons.category),
                            color: Color(int.parse(_color.replaceFirst('#', '0xff'))),
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

/// Carte « Année scolaire » : archive l'année écoulée puis repart à vide.
///
/// Doublonne volontairement la RAZ selective voisine : celle-ci efface sans
/// filet, alors que le passage a l'annee suivante garantit qu'une archive
/// complete existe sur le disque avant que quoi que ce soit ne disparaisse.
class _SchoolYearCard extends StatefulWidget {
  const _SchoolYearCard({required this.provider});

  final AppStateProvider provider;

  @override
  State<_SchoolYearCard> createState() => _SchoolYearCardState();
}

class _SchoolYearCardState extends State<_SchoolYearCard> {
  List<SchoolYearArchive> _archives = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final archives = await widget.provider.listArchives();
    if (!mounted) return;
    setState(() => _archives = archives);
  }

  void _toast(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF4E9F3D) : Colors.red,
      ),
    );
  }

  static String _anneeSuivante(String annee) {
    // « 2026-2027 » -> « 2027-2028 ». Toute autre forme est laissee a
    // l'enseignante : mieux vaut un champ a corriger qu'une annee fausse.
    final match = RegExp(r'^(\d{4})\s*[-/]\s*(\d{4})$').firstMatch(annee.trim());
    if (match == null) return '';
    return '${int.parse(match.group(1)!) + 1}-${int.parse(match.group(2)!) + 1}';
  }

  Future<void> _confirmerNouvelleAnnee() async {
    final provider = widget.provider;
    final anneeActuelle = provider.classSettings.schoolYear;
    final controller =
        TextEditingController(text: _anneeSuivante(anneeActuelle));
    final childCount = provider.children.length;
    final activityCount = provider.activities.length;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passer à l\'année suivante ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$childCount élève${childCount > 1 ? 's' : ''} et $activityCount '
              'observation${activityCount > 1 ? 's' : ''} de $anneeActuelle vont '
              'être archivés dans un fichier ZIP, puis effacés de la classe.\n\n'
              'Vos espaces, ateliers, niveaux d\'évaluation et groupes sont '
              'conservés. Si l\'archive ne peut pas être écrite, rien ne sera '
              'effacé.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nouvelle année scolaire',
                hintText: '2027-2028',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Archiver et vider'),
          ),
        ],
      ),
    );

    final nouvelleAnnee = controller.text.trim();
    controller.dispose();
    if (confirme != true) return;
    if (nouvelleAnnee.isEmpty) {
      _toast('Indiquez la nouvelle année scolaire.', success: false);
      return;
    }

    setState(() => _busy = true);
    final archive = await provider.startNewSchoolYear(nouvelleAnnee: nouvelleAnnee);
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
    _toast(
      archive == null
          ? 'Archivage impossible : aucune donnée n\'a été effacée.'
          : 'Année $anneeActuelle archivée. Bonne rentrée !',
      success: archive != null,
    );
  }

  Future<void> _partager(SchoolYearArchive archive) async {
    final ok = await widget.provider.shareArchive(archive);
    if (!ok) _toast('Fichier d\'archive introuvable sur l\'appareil.', success: false);
  }

  Future<void> _supprimer(SchoolYearArchive archive) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette archive ?'),
        content: Text(
          'L\'archive de ${archive.schoolYear} sera définitivement supprimée de '
          'l\'appareil. Si vous ne l\'avez pas partagée ailleurs, ces données '
          'seront perdues.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await widget.provider.deleteArchive(archive);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final annee = widget.provider.classSettings.schoolYear;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_outlined, color: Color(0xFF4E9F3D)),
                SizedBox(width: 8),
                Text('Année scolaire',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Année en cours : $annee. À la rentrée, archivez l\'année écoulée '
              '(données et photos) puis repartez sur une classe vide en '
              'conservant vos espaces et ateliers.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _confirmerNouvelleAnnee,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Passer à l\'année suivante'),
            ),
            if (_archives.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Années archivées',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ..._archives.map((archive) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_zip_outlined),
                    title: Text(archive.schoolYear,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${archive.childCount} élèves · ${archive.activityCount} '
                      'observations · ${(archive.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Partager',
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _partager(archive),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _supprimer(archive),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
