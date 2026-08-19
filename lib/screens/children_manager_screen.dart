import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/child.dart';
import '../services/child_activity_report_service.dart';
import '../utils/pdf_viewer.dart';
import 'child_profile_screen.dart';

enum ChildFilterMode { all, pendingToday, evaluatedToday }

class ChildrenManagerScreen extends StatefulWidget {
  const ChildrenManagerScreen({super.key});

  @override
  State<ChildrenManagerScreen> createState() => _ChildrenManagerScreenState();
}

class _ChildrenManagerScreenState extends State<ChildrenManagerScreen> {
  String _searchQuery = '';
  ChildFilterMode _filterMode = ChildFilterMode.all;

  Widget _buildChildAvatar(Child child, AppStateProvider provider) {
    final absolutePath = provider.getAbsolutePath(child.imagePath);
    final avatar = (absolutePath != null && File(absolutePath).existsSync())
        ? CircleAvatar(
            radius: 24,
            backgroundImage: FileImage(File(absolutePath)),
          )
        : CircleAvatar(
            radius: 24,
            backgroundColor: Color(int.parse(child.colorHex.replaceFirst('#', '0xff'))),
            child: Text(child.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          );
    if (child.imageAuthorized) return avatar;
    // Autorisation photo non renseignee : le rappel visuel evite d'avoir a
    // ouvrir chaque fiche pour savoir qui demander aux familles.
    return Stack(
      children: [
        avatar,
        Positioned(
          bottom: -2,
          right: -2,
          child: Tooltip(
            message: 'Autorisation photo non accordée',
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.no_photography, size: 14, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final now = DateTime.now();

    final allChildren = provider.children;

    // Comptage via l'index du provider : la version precedente rebalayait
    // toutes les observations pour chaque eleve, a chaque reconstruction.
    final Map<String, int> todayActivityCounts = {
      for (final child in allChildren)
        child.id: provider.activityCountForChildOn(child.id, now),
    };

    final pendingTodayCount = allChildren.where((c) => (todayActivityCounts[c.id] ?? 0) == 0).length;
    final evaluatedTodayCount = allChildren.where((c) => (todayActivityCounts[c.id] ?? 0) > 0).length;

    // Filter list
    final filteredChildren = allChildren.where((child) {
      // 1. Text Search
      final nameMatches = '${child.firstname} ${child.lastname ?? ""}'.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (child.group ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      // 2. Status Filter
      final todayCount = todayActivityCounts[child.id] ?? 0;
      if (_filterMode == ChildFilterMode.pendingToday && todayCount > 0) return false;
      if (_filterMode == ChildFilterMode.evaluatedToday && todayCount == 0) return false;

      return true;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChildDialog(context, provider),
        backgroundColor: const Color(0xFF4E9F3D),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter Élève', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── SEARCH & FILTER HEADER ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un élève, groupe...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Tous (${allChildren.length})'),
                        selected: _filterMode == ChildFilterMode.all,
                        selectedColor: const Color(0xFF4E9F3D).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF4E9F3D),
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.all),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('⏳ En attente ($pendingTodayCount)'),
                        selected: _filterMode == ChildFilterMode.pendingToday,
                        selectedColor: Colors.amber.withOpacity(0.2),
                        checkmarkColor: Colors.amber.shade900,
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.pendingToday),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('✅ Évalués aujourd\'hui ($evaluatedTodayCount)'),
                        selected: _filterMode == ChildFilterMode.evaluatedToday,
                        selectedColor: const Color(0xFF4E9F3D).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF4E9F3D),
                        onSelected: (_) => setState(() => _filterMode = ChildFilterMode.evaluatedToday),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CHILDREN LIST ──
          Expanded(
            child: filteredChildren.isEmpty
                ? const Center(
                    child: Text('Aucun élève ne correspond à la recherche.'),
                  )
                : ListView.builder(
                    // Marge basse degagee pour le bouton flottant, qui
                    // recouvrait sinon la derniere fiche de la liste.
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filteredChildren.length,
                    itemBuilder: (context, index) {
                      final child = filteredChildren[index];
                      final todayCount = todayActivityCounts[child.id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildProfileScreen(child: child),
                              ),
                            );
                          },
                          leading: _buildChildAvatar(child, provider),
                          title: Text('${child.firstname} ${child.lastname ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(child.group ?? 'Sans groupe', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              todayCount > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4E9F3D).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✅ $todayCount activité(s) aujourd\'hui',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D)),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⏳ En attente d\'activité',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4E9F3D)),
                                onPressed: () => _choosePdfPeriod(context, child, provider),
                                tooltip: 'Générer le rapport PDF',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── PDF PERIOD PICKER ───────────────────
  void _choosePdfPeriod(BuildContext context, Child child, AppStateProvider provider) {
    DateTimeRange? customRange;
    bool onlyLatestPerAtelier = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.date_range, color: Color(0xFF4E9F3D)),
                  SizedBox(width: 8),
                  Text('Période du rapport'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choisissez la période à inclure dans le rapport PDF :',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  _periodButton(
                    context: context,
                    label: 'Toute la période',
                    icon: Icons.all_inclusive,
                    onTap: () {
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider, null, null, onlyLatestPerAtelier);
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: 'Ce mois-ci',
                    icon: Icons.calendar_month,
                    onTap: () {
                      final now = DateTime.now();
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider,
                          DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0), onlyLatestPerAtelier);
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: 'Semaine en cours',
                    icon: Icons.view_week,
                    onTap: () {
                      final now = DateTime.now();
                      final monday = now.subtract(Duration(days: now.weekday - 1));
                      Navigator.pop(context);
                      _openPdfPreview(context, child, provider,
                          DateTime(monday.year, monday.month, monday.day),
                          DateTime(monday.year, monday.month, monday.day + 6, 23, 59), onlyLatestPerAtelier);
                    },
                  ),
                  const SizedBox(height: 8),
                  _periodButton(
                    context: context,
                    label: customRange != null
                        ? '${DateFormat('dd/MM').format(customRange!.start)} → ${DateFormat('dd/MM').format(customRange!.end)}'
                        : 'Période personnalisée…',
                    icon: Icons.tune,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) {
                        setDialogState(() => customRange = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Occurrence la plus récente seulement', style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      "Sinon, toutes les fois où l'atelier a été refait apparaissent.",
                      style: TextStyle(fontSize: 11),
                    ),
                    value: onlyLatestPerAtelier,
                    activeColor: const Color(0xFF4E9F3D),
                    onChanged: (val) => setDialogState(() => onlyLatestPerAtelier = val),
                  ),
                  if (customRange != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openPdfPreview(context, child, provider, customRange!.start,
                              customRange!.end.add(const Duration(days: 1)), onlyLatestPerAtelier);
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Générer le PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E9F3D),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _periodButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ─────────────────── ADD/EDIT CHILD DIALOG ───────────────────
  void _openChildDialog(BuildContext context, AppStateProvider provider, {Child? child}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChildFormDialog(provider: provider, child: child),
      ),
    );
  }

  // ─────────────────── PDF PREVIEW ───────────────────

  Future<void> _openPdfPreview(
    BuildContext context,
    Child child,
    AppStateProvider provider,
    DateTime? from,
    DateTime? to, [
    bool onlyLatestPerAtelier = false,
  ]) async {
    String periodLabel = 'Toute la période';
    if (from != null && to != null) {
      periodLabel = '${DateFormat('dd/MM/yyyy').format(from)} → ${DateFormat('dd/MM/yyyy').format(to.subtract(const Duration(days: 1)))}';
    }

    openPdfViewer(
      context,
      title: 'Rapport - ${child.firstname} ($periodLabel)',
      fileName: 'Rapport_${child.firstname}_${child.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
      build: (format) => ChildActivityReportService.generateChildReportBytes(
        child: child,
        provider: provider,
        format: format,
        from: from,
        to: to,
        onlyLatestPerAtelier: onlyLatestPerAtelier,
      ),
      shareBody: 'Veuillez trouver ci-joint le rapport d\'activités de ${child.firstname}.',
      shareSubject: 'Rapport d\'activités - ${child.firstname}',
      shareEmails: child.email != null && child.email!.isNotEmpty ? [child.email!] : null,
    );
  }

}

// ─── Proper StatefulWidget for Child form dialog ───
class ChildFormDialog extends StatefulWidget {
  final AppStateProvider provider;
  final Child? child;

  const ChildFormDialog({super.key, required this.provider, this.child});

  @override
  State<ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<ChildFormDialog> {
  late final TextEditingController _firstnameController;
  late final TextEditingController _lastnameController;
  late final TextEditingController _groupController;
  late final TextEditingController _notesController;
  late final TextEditingController _emailController;
  String? _relativeImagePath;
  String? _selectedImagePath;
  DateTime? _birthdate;
  late bool _imageAuthorized;

  @override
  void initState() {
    super.initState();
    final child = widget.child;
    final provider = widget.provider;
    _firstnameController = TextEditingController(text: child?.firstname ?? '');
    _lastnameController = TextEditingController(text: child?.lastname ?? '');
    _groupController = TextEditingController(
      text: child?.group ?? (provider.sections.isNotEmpty ? provider.sections.first : ''),
    );
    _notesController = TextEditingController(text: child?.notes ?? '');
    _emailController = TextEditingController(text: child?.email ?? '');
    _relativeImagePath = child?.imagePath;
    _selectedImagePath = provider.getAbsolutePath(child?.imagePath);
    _birthdate = child?.birthdate != null ? DateTime.tryParse(child!.birthdate!) : null;
    _imageAuthorized = child?.imageAuthorized ?? false;
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _groupController.dispose();
    _notesController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final relPath = await widget.provider.pickAndSavePhoto(
      source: source,
      subDir: 'profiles',
    );
    if (relPath != null && mounted) {
      setState(() {
        _relativeImagePath = relPath;
        _selectedImagePath = widget.provider.getAbsolutePath(relPath);
      });
    }
  }

  bool get _hasValidImage {
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) return false;
    return File(_selectedImagePath!.replaceFirst('file://', '')).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final provider = widget.provider;

    return Scaffold(
      appBar: AppBar(
        title: Text(child == null ? 'Ajouter un Élève' : 'Modifier Élève'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar / Photo Selection — verrouille tant que l'autorisation
            // droit a l'image n'est pas cochee.
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _imageAuthorized ? () => _pickPhoto(ImageSource.gallery) : null,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (_imageAuthorized && _hasValidImage)
                          ? FileImage(File(_selectedImagePath!.replaceFirst('file://', '')))
                          : null,
                      child: !(_imageAuthorized && _hasValidImage)
                          ? Icon(
                              _imageAuthorized ? Icons.add_a_photo : Icons.no_photography,
                              size: 28,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_imageAuthorized)
                    TextButton.icon(
                      icon: const Icon(Icons.photo_camera, size: 14),
                      label: const Text('Appareil photo', style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Autorisation photo requise avant d\'ajouter une image',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF4E9F3D),
              title: const Text('Autorisation droit à l\'image',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'À cocher une fois l\'autorisation photo donnée par les parents. '
                'Sans elle, aucune photo ne peut être ajoutée pour cet élève.',
                style: TextStyle(fontSize: 11),
              ),
              value: _imageAuthorized,
              onChanged: (val) => setState(() {
                _imageAuthorized = val ?? false;
                if (!_imageAuthorized) {
                  // Le retrait de l'autorisation efface aussi la photo deja
                  // en place : la garder contredirait le blocage.
                  _relativeImagePath = null;
                  _selectedImagePath = null;
                }
              }),
            ),
            const SizedBox(height: 12),
            TextField(controller: _firstnameController, decoration: const InputDecoration(labelText: 'Prénom *')),
            const SizedBox(height: 10),
            TextField(controller: _lastnameController, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickBirthdate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date de naissance',
                  border: const OutlineInputBorder(),
                  suffixIcon: _birthdate == null
                      ? const Icon(Icons.calendar_today, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _birthdate = null),
                        ),
                ),
                child: Text(
                  _birthdate != null ? DateFormat('dd/MM/yyyy').format(_birthdate!) : 'Non renseignée',
                  style: TextStyle(color: _birthdate != null ? null : Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Sections gerees dans les parametres. Le groupe deja enregistre
            // est ajoute a la liste s'il n'y figure plus, pour ne pas le
            // remplacer silencieusement a l'enregistrement.
            Builder(
              builder: (context) {
                final current = _groupController.text.trim();
                final options = [
                  ...widget.provider.sections,
                  if (current.isNotEmpty && !widget.provider.sections.contains(current)) current,
                ];
                return DropdownButtonFormField<String>(
                  value: options.contains(current) ? current : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Groupe / Section',
                    border: OutlineInputBorder(),
                    helperText: 'Modifiable dans Paramètres > Ma classe',
                  ),
                  hint: const Text('Choisir une section'),
                  items: options
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _groupController.text = val);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email des parents')),
            const SizedBox(height: 10),
            TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_firstnameController.text.trim().isEmpty) return;

                  final newChild = Child(
                    id: child?.id ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
                    firstname: _firstnameController.text.trim(),
                    lastname: _lastnameController.text.trim(),
                    birthdate: _birthdate != null ? DateFormat('yyyy-MM-dd').format(_birthdate!) : null,
                    group: _groupController.text.trim(),
                    notes: _notesController.text.trim(),
                    email: _emailController.text.trim(),
                    colorHex: child?.colorHex ?? '#4E9F3D',
                    avatarText: _firstnameController.text.trim()[0].toUpperCase(),
                    imagePath: _relativeImagePath,
                    imageAuthorized: _imageAuthorized,
                  );
                  provider.addOrUpdateChild(newChild);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
