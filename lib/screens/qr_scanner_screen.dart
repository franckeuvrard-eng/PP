import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/dictation_button.dart';
import 'student_mode_screen.dart';
import '../widgets/photo_thumb.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../services/atelier_eligibility_service.dart';
import '../services/atelier_grouping.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import '../utils/platform_support.dart';
import '../widgets/voice_note_field.dart';

/// Mode de saisie choisi sur le premier ecran.
enum _ScanMode { qr, manual }

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  String? _selectedChildId;
  String? _selectedActivityTypeId;
  String? _selectedEvaluationStatusId;
  final TextEditingController _noteController = TextEditingController();
  final List<String> _selectedPhotoPaths = [];
  final Map<String, String> _photoCaptions = {};
  String? _audioPath;

  /// Eleves supplementaires pour la saisie groupee : le meme atelier est
  /// enregistre pour chacun, avec la meme note et les memes photos.
  final Set<String> _extraChildIds = {};

  /// Null : premier ecran (choix du mode). Sur ordinateur, sans camera, on
  /// passe directement a la selection manuelle.
  _ScanMode? _mode = isMobilePlatform ? null : _ScanMode.manual;

  final TextEditingController _childSearchCtrl = TextEditingController();
  final TextEditingController _atelierSearchCtrl = TextEditingController();
  String _childQuery = '';
  String _atelierQuery = '';

  /// Selection manuelle : etapes de parcours plutot qu'ateliers.
  bool _pickParcours = false;

  @override
  void dispose() {
    _noteController.dispose();
    _childSearchCtrl.dispose();
    _atelierSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _editPhotoCaption(String path) async {
    final ctrl = TextEditingController(text: _photoCaptions[path] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Commentaire de la photo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ce que montre la photo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
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
        _photoCaptions.remove(path);
      } else {
        _photoCaptions[path] = result;
      }
    });
  }

  Future<void> _pickExtraChildren(AppStateProvider provider) async {
    final selection = Set<String>.from(_extraChildIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSt) => AlertDialog(
          title: const Text('Autres élèves concernés'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(children: [
              // Groupes de besoin : tout le groupe d'un geste (sauf l'eleve
              // deja choisi).
              if (provider.needGroups.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final g in provider.needGroups)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: () {
                            // Seulement ceux pour qui l'atelier est ouvert
                            // (une etape verrouillee ne s'enregistre pas).
                            final atelier = provider.activityTypeById(_selectedActivityTypeId);
                            final ids = {
                              for (final id in g.childIds)
                                if (id != _selectedChildId)
                                  if (provider.childById(id) case final c?)
                                    if (atelier == null ||
                                        AtelierEligibilityService.evaluate(
                                                provider: provider, child: c, atelier: atelier)
                                            .isAllowed)
                                      id,
                            };
                            return FilterChip(
                              avatar: const Icon(Icons.groups, size: 16),
                              label: Text(g.name),
                              selected: ids.isNotEmpty && selection.containsAll(ids),
                              onSelected: (_) => setSt(() {
                                if (selection.containsAll(ids)) {
                                  selection.removeAll(ids);
                                } else {
                                  selection.addAll(ids);
                                }
                              }),
                            );
                          }(),
                        ),
                    ],
                  ),
                ),
              Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                children: provider.children
                    .where((c) => c.id != _selectedChildId)
                    .where((c) {
                      if (_selectedActivityTypeId == null) return true;
                      final atelier = provider.activityTypeById(_selectedActivityTypeId);
                      if (atelier == null) return true;
                      return AtelierEligibilityService.evaluate(provider: provider, child: c, atelier: atelier)
                          .isAllowed;
                    })
                    .map((c) => CheckboxListTile(
                          dense: true,
                          value: selection.contains(c.id),
                          activeColor: const Color(0xFF4E9F3D),
                          title: Text('${c.firstname} ${c.lastname ?? ''}'.trim()),
                          subtitle: c.group == null || c.group!.isEmpty
                              ? null
                              : Text(c.group!, style: const TextStyle(fontSize: 12)),
                          onChanged: (checked) => setSt(() {
                            if (checked == true) {
                              selection.add(c.id);
                            } else {
                              selection.remove(c.id);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, selection),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _extraChildIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _startQrScanner(BuildContext context, AppStateProvider provider) async {
    if (!isMobilePlatform) {
      // mobile_scanner n'a pas d'implementation poste de travail : ouvrir la
      // route camera y provoquerait une MissingPluginException.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le scan QR n\'est disponible que sur iPhone et iPad.')),
      );
      return;
    }

    final result = await Navigator.push<Map<String, String?>>(
      context,
      MaterialPageRoute(
        builder: (context) => QrCameraScannerOverlay(
          children: provider.children,
          activityTypes: provider.activityTypes,
          initialChildId: _selectedChildId,
          initialActivityTypeId: _selectedActivityTypeId,
        ),
      ),
    );

    // L'ecran de scan peut avoir ete quitte pendant que la camera se fermait.
    // Les deux gardes sont necessaires : `mounted` couvre le setState, et
    // `context.mounted` le ScaffoldMessenger, le contexte etant recu en
    // parametre et pouvant donc venir d'un autre arbre que cet Etat.
    if (!mounted || !context.mounted) return;

    if (result != null) {
      setState(() {
        if (result['childId'] != null) {
          _selectedChildId = result['childId'];
        }
        if (result['activityTypeId'] != null) {
          _selectedActivityTypeId = result['activityTypeId'];
        }
      });

      if (_selectedChildId != null && _selectedActivityTypeId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Élève et Atelier associés avec succès !'),
            backgroundColor: Color(0xFF4E9F3D),
          ),
        );
      }
    }
  }

  Future<void> _pickPhotos() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final ImagePicker picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Sélectionner de la galerie (multiples)'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final List<XFile> images = await picker.pickMultiImage(
                      maxWidth: AppStateProvider.photoMaxSize.toDouble(),
                      maxHeight: AppStateProvider.photoMaxSize.toDouble(),
                      imageQuality: AppStateProvider.photoQuality,
                    );
                    for (final img in images) {
                      final relPath = await provider.saveXFileToDocs(img, 'activities');
                      final absPath = provider.getAbsolutePath(relPath);
                      if (absPath != null && mounted) {
                        setState(() {
                          _selectedPhotoPaths.add(absPath);
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint('Error picking multi image: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final relPath = await provider.pickAndSavePhoto(
                    source: ImageSource.camera,
                    subDir: 'activities',
                  );
                  if (relPath != null) {
                    final absPath = provider.getAbsolutePath(relPath);
                    if (absPath != null && mounted) {
                      setState(() {
                        _selectedPhotoPaths.add(absPath);
                      });
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Prenoms des eleves cibles (principal + "Enregistrer aussi pour") qui
  /// n'ont pas l'autorisation droit a l'image.
  List<String> _unauthorizedTargets(AppStateProvider provider) {
    final targetIds = <String>{
      if (_selectedChildId != null) _selectedChildId!,
      ..._extraChildIds,
    };
    return targetIds
        .map((id) => provider.children.where((c) => c.id == id).firstOrNull)
        .whereType<Child>()
        .where((c) => !c.imageAuthorized)
        .map((c) => c.firstname)
        .toList();
  }

  Widget _buildPhotoSelector() {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final unauthorized = _selectedPhotoPaths.isNotEmpty ? _unauthorizedTargets(provider) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos associées',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (unauthorized.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pas d\'autorisation photo pour ${unauthorized.join(", ")} — évitez de '
                    'l\'inclure/les inclure dans ces photos.',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 124,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              ..._selectedPhotoPaths.asMap().entries.map((entry) {
                final int index = entry.key;
                final String path = entry.value;
                final caption = _photoCaptions[path];
                final hasCaption = caption != null && caption.trim().isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          PhotoThumb(
                              path: path.replaceFirst('file://', ''), size: 80, radius: 16),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPhotoPaths.removeAt(index);
                                  _photoCaptions.remove(path);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 80,
                        child: TextButton.icon(
                          onPressed: () => _editPhotoCaption(path),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(hasCaption ? Icons.edit_note : Icons.add_comment, size: 13),
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
    );
  }

  /// Recherche sans tenir compte des accents ni des majuscules.
  static String _norm(String s) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  bool get _ready => _selectedChildId != null && _selectedActivityTypeId != null;

  void _resetSelection() {
    _selectedChildId = null;
    _selectedActivityTypeId = null;
    _childQuery = '';
    _atelierQuery = '';
    _childSearchCtrl.clear();
    _atelierSearchCtrl.clear();
  }

  /// Choisit l'eleve ; l'atelier deja choisi est garde s'il lui reste ouvert.
  void _selectChild(AppStateProvider provider, String id) {
    setState(() {
      _selectedChildId = id;
      _childQuery = '';
      _childSearchCtrl.clear();
    });
    final previous = provider.activityTypeById(_selectedActivityTypeId);
    final child = provider.childById(id);
    if (previous == null || child == null) return;
    if (!AtelierEligibilityService.evaluate(provider: provider, child: child, atelier: previous).isAllowed) {
      setState(() => _selectedActivityTypeId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("L'atelier précédemment choisi n'est plus disponible pour cet élève."),
      ));
    }
  }

  /// Premier ecran : scanner des QR codes ou tout choisir a la main.
  Widget _buildModeChoice(AppStateProvider provider) {
    Widget card({
      required IconData icon,
      required Color color,
      required String title,
      required String text,
      required VoidCallback onTap,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(text, style: const TextStyle(fontSize: 13, color: kMutedTextColor)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text('Comment voulez-vous saisir l\'observation ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        card(
          icon: Icons.qr_code_scanner,
          color: const Color(0xFFFF7043),
          title: 'Scanner les QR codes',
          text: 'Badge de l\'élève et étiquette de l\'atelier ou de l\'étape, dans n\'importe quel ordre.',
          onTap: () {
            setState(() => _mode = _ScanMode.qr);
            _startQrScanner(context, provider);
          },
        ),
        card(
          icon: Icons.touch_app,
          color: const Color(0xFF4E9F3D),
          title: 'Sélection manuelle',
          text: 'Recherchez l\'élève, puis l\'atelier par domaine ou l\'étape par parcours.',
          onTap: () => setState(() => _mode = _ScanMode.manual),
        ),
        card(
          icon: Icons.child_care,
          color: const Color(0xFF8E24AA),
          title: 'Mode élève (tablette)',
          text: 'Les enfants notent eux-mêmes ce qu\'ils ont fait ; vous validez ensuite. Sortie protégée.',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(fullscreenDialog: true, builder: (_) => const StudentModeScreen())),
        ),
      ],
    );
  }

  /// Bandeau du haut : mode en cours, eleve et atelier choisis (touchez-les
  /// pour les changer).
  Widget _buildStepHeader(AppStateProvider provider) {
    final child = provider.childById(_selectedChildId);
    final atelier = provider.activityTypeById(_selectedActivityTypeId);
    final qr = _mode == _ScanMode.qr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(qr ? Icons.qr_code_scanner : Icons.touch_app,
                color: qr ? const Color(0xFFFF7043) : const Color(0xFF4E9F3D)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(qr ? 'Scan des QR codes' : 'Sélection manuelle',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            // Ordinateur : pas d'ecran de choix, le mode eleve s'ouvre d'ici.
            if (!isMobilePlatform)
              TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const StudentModeScreen())),
                icon: const Icon(Icons.child_care, size: 18),
                label: const Text('Mode élève'),
              ),
            if (isMobilePlatform)
              TextButton.icon(
                onPressed: () => setState(() {
                  _resetSelection();
                  _mode = null;
                }),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Changer de mode'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InputChip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text(child == null ? 'Élève' : _fullName(child)),
              selected: child != null,
              onPressed: child == null || qr ? null : () => setState(() => _selectedChildId = null),
              onDeleted: child == null ? null : () => setState(() => _selectedChildId = null),
            ),
            InputChip(
              avatar: Icon(atelier?.inProgression ?? false ? Icons.flag : Icons.category, size: 18),
              label: Text(atelier == null ? 'Atelier ou étape' : atelier.name),
              selected: atelier != null,
              onPressed: atelier == null || qr ? null : () => setState(() => _selectedActivityTypeId = null),
              onDeleted: atelier == null ? null : () => setState(() => _selectedActivityTypeId = null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (qr && !_ready) ...[
          ElevatedButton.icon(
            onPressed: () => _startQrScanner(context, provider),
            icon: const Icon(Icons.photo_camera, size: 22),
            label: Text(child == null && atelier == null ? 'Scanner' : 'Scanner le QR code manquant',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ] else if (!qr && child == null)
          _buildChildPicker(provider)
        else if (!qr && atelier == null)
          _buildAtelierPicker(provider, child!),
      ],
    );
  }

  static String _fullName(Child c) => '${c.firstname} ${c.lastname ?? ''}'.trim();

  Widget _searchField(TextEditingController ctrl, String hint, ValueChanged<String> onChanged) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  ctrl.clear();
                  onChanged('');
                },
              ),
      ),
      onChanged: onChanged,
    );
  }

  /// Etape 1 (manuel) : l'eleve, en tapant un bout de son prenom ou nom.
  Widget _buildChildPicker(AppStateProvider provider) {
    final q = _norm(_childQuery.trim());
    final list = provider.children
        .where((c) => q.isEmpty || _norm(_fullName(c)).contains(q) || _norm(c.group ?? '').contains(q))
        .toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('1. Quel élève ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        _searchField(_childSearchCtrl, 'Prénom ou nom (quelques lettres suffisent)',
            (v) => setState(() => _childQuery = v)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Aucun élève ne correspond.', style: TextStyle(color: kMutedTextColor)),
          ),
        for (final c in list)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: hexToColor(c.colorHex),
                child: Text(c.avatarText.isNotEmpty ? c.avatarText : c.firstname.characters.first,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(_fullName(c), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: c.group == null || c.group!.isEmpty ? null : Text(c.group!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectChild(provider, c.id),
            ),
          ),
      ],
    );
  }

  /// Etape 2 (manuel) : l'atelier, range par domaine puis sous-domaine, ou
  /// l'etape, rangee par parcours.
  Widget _buildAtelierPicker(AppStateProvider provider, Child child) {
    final q = _norm(_atelierQuery.trim());
    final searching = q.isNotEmpty;
    final results = {
      for (final e in AtelierEligibilityService.annotate(provider: provider, child: child)) e.key.id: e.value,
    };

    Widget atelierTile(ActivityType a, {String? leadingNumber}) {
      final r = results[a.id]!;
      final blocked = !r.isAllowed;
      final warn = r.status == AtelierEligibility.allowedWithWarning;
      return ListTile(
        dense: true,
        enabled: !blocked,
        leading: leadingNumber != null
            ? CircleAvatar(
                radius: 14,
                backgroundColor: blocked ? Colors.grey : hexToColor(a.colorHex),
                child: Text(leadingNumber,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            : CircleAvatar(
                radius: 14,
                backgroundColor: hexToColor(a.colorHex),
                child: Icon(iconForName(a.iconName, fallback: Icons.palette), size: 14, color: Colors.white),
              ),
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: blocked || warn ? Text(r.message, style: const TextStyle(fontSize: 11)) : null,
        trailing: blocked
            ? const Icon(Icons.lock, size: 18, color: Colors.grey)
            : warn
                ? const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange)
                : const Icon(Icons.chevron_right),
        onTap: blocked ? null : () => setState(() => _selectedActivityTypeId = a.id),
      );
    }

    final List<Widget> groups;
    if (!_pickParcours) {
      // Ateliers des espaces proposes a cet eleve (sections comprises).
      final ateliers = provider.activityTypes.where((a) => !a.inProgression && results[a.id]!.isAllowed).where((a) {
        if (!searching) return true;
        return _norm('${a.name} ${AtelierGrouping.domainTitleOf(a)} '
                '${AtelierGrouping.subdomainTitlesOf(a).join(' ')} ${provider.placeOf(a)?.name ?? ''}')
            .contains(q);
      });
      groups = [
        for (final d in AtelierGrouping.byDomain(ateliers))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              key: ValueKey('d_${d.key}_$searching'),
              initiallyExpanded: searching,
              title: Text(d.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${d.value.length} atelier(s)', style: const TextStyle(fontSize: 12)),
              children: [
                for (final s in AtelierGrouping.bySubdomain(d.value))
                  // Un seul groupe « Autres » : pas de sous-niveau inutile.
                  if (AtelierGrouping.bySubdomain(d.value).length == 1 &&
                      s.key == AtelierGrouping.otherSubdomain)
                    ...s.value.map(atelierTile)
                  else
                    ExpansionTile(
                      key: ValueKey('s_${d.key}_${s.key}_$searching'),
                      initiallyExpanded: searching,
                      tilePadding: const EdgeInsets.only(left: 24, right: 16),
                      childrenPadding: const EdgeInsets.only(left: 16),
                      title: Text(s.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.value.length} atelier(s)', style: const TextStyle(fontSize: 11)),
                      children: s.value.map(atelierTile).toList(),
                    ),
              ],
            ),
          ),
      ];
    } else {
      groups = [
        for (final p in provider.progressions)
          () {
            final steps = provider.ateliersInProgressionOrdered(p.id);
            final shown = [
              for (final (i, s) in steps.indexed)
                if (!searching || _norm('${p.name} ${s.name}').contains(q)) (i, s),
            ];
            if (shown.isEmpty) return const SizedBox.shrink();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                key: ValueKey('p_${p.id}_$searching'),
                // Seul parcours ou recherche : deplie d'emblee.
                initiallyExpanded: searching || provider.progressions.length == 1,
                leading: Icon(iconForName(p.iconName, fallback: Icons.timeline), color: hexToColor(p.colorHex)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    p.concernsGroup(child.group)
                        ? '${steps.length} étape(s)'
                        : '${steps.length} étape(s) · pas prévu pour cette section',
                    style: const TextStyle(fontSize: 12)),
                children: [for (final (i, s) in shown) atelierTile(s, leadingNumber: '${i + 1}')],
              ),
            );
          }(),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('2. Quel atelier ou quelle étape ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        // Planning : ce qui est prevu aujourd'hui pour cet eleve, en tete.
        if (!searching)
          if ([
            for (final id in provider.plannedAteliersFor(child, DateTime.now()))
              if (provider.activityTypeById(id) case final a?)
                if (results[a.id]?.isAllowed ?? false) a,
          ]
              case final planned when planned.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: const Color(0xFFE8833A).withValues(alpha: 0.10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Icon(Icons.calendar_view_week, size: 18, color: Color(0xFFE8833A)),
                    SizedBox(width: 8),
                    Text('Prévu aujourd\'hui', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
                for (final a in planned) atelierTile(a),
              ]),
            ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.category), label: Text('Ateliers')),
            ButtonSegment(value: true, icon: Icon(Icons.timeline), label: Text('Parcours')),
          ],
          selected: {_pickParcours},
          onSelectionChanged: (sel) => setState(() => _pickParcours = sel.first),
        ),
        const SizedBox(height: 8),
        _searchField(
            _atelierSearchCtrl,
            _pickParcours ? 'Rechercher un parcours ou une étape' : 'Rechercher un atelier, un domaine, un sous-domaine',
            (v) => setState(() => _atelierQuery = v)),
        const SizedBox(height: 8),
        if (groups.whereType<Card>().isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
                _pickParcours ? 'Aucune étape ne correspond.' : 'Aucun atelier ne correspond.',
                style: const TextStyle(color: kMutedTextColor)),
          ),
        ...groups,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    if (_mode == null) return _buildModeChoice(provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // Etait Colors.white en dur : en mode sombre, le texte clair du
              // theme devenait illisible sur ce fond blanc.
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepHeader(provider),

                // La suite (statut, photos, note) une fois l'eleve et
                // l'atelier choisis.
                if (_ready) ...[
                // Customizable Evaluation Status
                if (provider.evaluationStatuses.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    // Champ pilote par le code (ex. eleve choisi par scan) : initialValue
                    // ne suivrait pas ses changements.
                    // ignore: deprecated_member_use
                    value: provider.evaluationStatuses.any((s) => s.id == _selectedEvaluationStatusId)
                        ? _selectedEvaluationStatusId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Statut de l\'évaluation *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.star_border),
                      helperText: _selectedEvaluationStatusId == null ? 'Requis pour enregistrer' : null,
                      helperStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    items: provider.evaluationStatuses.map((status) {
                      return DropdownMenuItem(
                        value: status.id,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: hexToColor(status.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(status.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedEvaluationStatusId = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // Multi-Photo Selector Widget
                _buildPhotoSelector(),

                const SizedBox(height: 20),

                TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Observation / Note pédagogique',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.comment),
                    // Dictee : la voix devient du texte, ecrit dans la note.
                    suffixIcon: DictationButton(controller: _noteController),
                  ),
                ),
                const SizedBox(height: 10),
                VoiceNoteField(
                  provider: provider,
                  audioPath: _audioPath,
                  onChanged: (path) => setState(() => _audioPath = path),
                ),

                const SizedBox(height: 20),

                // Saisie groupee : meme atelier, meme note, memes photos pour
                // plusieurs eleves a la fois.
                if (_selectedChildId != null) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Enregistrer aussi pour :',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickExtraChildren(provider),
                        icon: const Icon(Icons.group_add, size: 18),
                        label: Text(_extraChildIds.isEmpty
                            ? 'Ajouter'
                            : '${_extraChildIds.length} élève(s)'),
                      ),
                    ],
                  ),
                  if (_extraChildIds.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _extraChildIds.map((id) {
                        final c = provider.children.firstWhere(
                          (c) => c.id == id,
                          orElse: () => Child(
                              id: id, firstname: '?', colorHex: '#718096', avatarText: '?'),
                        );
                        return Chip(
                          label: Text('${c.firstname} ${c.lastname ?? ''}'.trim(),
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _extraChildIds.remove(id)),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: (_selectedChildId != null &&
                          _selectedActivityTypeId != null &&
                          (provider.evaluationStatuses.isEmpty || _selectedEvaluationStatusId != null))
                      ? () async {
                          // Copy all picked photos permanently to Documents
                          final List<String> savedRelativePaths = [];
                          final Map<String, String> savedCaptions = {};
                          for (final absPath in _selectedPhotoPaths) {
                            String? relPath;
                            if (absPath.contains('activities/')) {
                              final filename = absPath.split('activities/').last;
                              relPath = 'activities/$filename';
                            } else if (File(absPath.replaceFirst('file://', '')).existsSync()) {
                              relPath = await provider.saveImageToDocs(absPath, 'activities');
                            }
                            if (relPath == null) continue;
                            savedRelativePaths.add(relPath);
                            // Les legendes sont saisies sur le chemin temporaire :
                            // on les rebascule sur le chemin definitif.
                            final caption = _photoCaptions[absPath];
                            if (caption != null && caption.trim().isNotEmpty) {
                              savedCaptions[relPath] = caption.trim();
                            }
                          }

                          // Saisie groupee : un enregistrement distinct par
                          // eleve, tous partageant atelier, note et photos.
                          final targetIds = <String>{_selectedChildId!, ..._extraChildIds};
                          final baseStamp = DateTime.now();
                          var offset = 0;
                          for (final childId in targetIds) {
                            provider.logActivity(ActivityLog(
                              // millisecondsSinceEpoch seul pourrait se repeter
                              // sur une boucle rapide : on decale chaque id.
                              id: 'log_${baseStamp.millisecondsSinceEpoch + offset}_$childId',
                              childId: childId,
                              activityTypeId: _selectedActivityTypeId!,
                              timestamp: baseStamp,
                              note: _noteController.text.trim(),
                              photoPaths: savedRelativePaths,
                              evaluationStatusId: _selectedEvaluationStatusId,
                              photoCaptions: savedCaptions,
                              audioPath: _audioPath,
                            ));
                            offset++;
                          }

                          unawaited(HapticFeedback.mediumImpact());
                          if (context.mounted) {
                            _showAnimatedSuccessOverlay(
                              context,
                              targetIds.length > 1
                                  ? '${targetIds.length} observations enregistrées ! 🎉'
                                  : 'Activité enregistrée avec succès ! 🎉',
                            );
                            if (_mode == _ScanMode.qr) {
                              // Apres l'animation de confirmation (1,4 s).
                              Future.delayed(const Duration(milliseconds: 1600), () {
                                if (mounted && context.mounted && _mode == _ScanMode.qr) {
                                  _startQrScanner(context, provider);
                                }
                              });
                            }
                            setState(() {
                              _resetSelection();
                              _selectedEvaluationStatusId = null;
                              _noteController.clear();
                              _selectedPhotoPaths.clear();
                              _photoCaptions.clear();
                              _extraChildIds.clear();
                              _audioPath = null;
                            });
                          }
                        }
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider et Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAnimatedSuccessOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (context.mounted) Navigator.pop(context);
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4E9F3D).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4E9F3D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Fullscreen Camera Scanner Overlay
class QrCameraScannerOverlay extends StatefulWidget {
  final List<Child> children;
  final List<ActivityType> activityTypes;
  final String? initialChildId;
  final String? initialActivityTypeId;

  const QrCameraScannerOverlay({
    super.key,
    required this.children,
    required this.activityTypes,
    this.initialChildId,
    this.initialActivityTypeId,
  });

  @override
  State<QrCameraScannerOverlay> createState() => _QrCameraScannerOverlayState();
}

class _QrCameraScannerOverlayState extends State<QrCameraScannerOverlay> {
  String? _scannedChildId;
  String? _scannedActivityTypeId;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isClosed = false;

  // Feedback states
  String? _scanMessage;
  bool _isErrorMessage = false;
  Timer? _messageTimer;

  // Duplicate prevention
  String? _lastScannedValue;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _scannedChildId = widget.initialChildId;
    _scannedActivityTypeId = widget.initialActivityTypeId;
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showScanMessage(String message, {required bool isError}) {
    _messageTimer?.cancel();
    setState(() {
      _scanMessage = message;
      _isErrorMessage = isError;
    });
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _scanMessage = null;
        });
      }
    });
  }

  void _triggerErrorVibration() {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.vibrate();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isClosed) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final now = DateTime.now();
      if (_lastScannedValue == rawValue &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!).inSeconds < 2) {
        continue;
      }

      _lastScannedValue = rawValue;
      _lastScanTime = now;

      debugPrint('Detected QR Code: $rawValue');

      if (rawValue.startsWith('PETITPAS:CHILD:')) {
        final childId = rawValue.replaceFirst('PETITPAS:CHILD:', '');
        final childIndex = widget.children.indexWhere((c) => c.id == childId);
        if (childIndex >= 0) {
          final newChild = widget.children[childIndex];
          HapticFeedback.mediumImpact();
          setState(() {
            _scannedChildId = childId;
            // Un atelier deja scanne peut ne plus convenir au nouvel eleve :
            // on revalide plutot que de garder une association incoherente.
            if (_scannedActivityTypeId != null) {
              final atelier =
                  widget.activityTypes.where((a) => a.id == _scannedActivityTypeId).firstOrNull;
              final provider = context.read<AppStateProvider>();
              final stillOk = atelier != null &&
                  AtelierEligibilityService.evaluate(provider: provider, child: newChild, atelier: atelier)
                      .isAllowed;
              if (!stillOk) _scannedActivityTypeId = null;
            }
          });
          _showScanMessage('Élève détecté : ${newChild.firstname}', isError: false);
          _checkAndAutoClose();
        } else {
          _triggerErrorVibration();
          _showScanMessage('Élève inconnu dans la base', isError: true);
        }
      } else if (rawValue.startsWith('PETITPAS:ACT:')) {
        if (_scannedChildId == null) {
          _triggerErrorVibration();
          _showScanMessage('Scannez d\'abord le badge de l\'élève', isError: true);
          continue;
        }
        final actId = rawValue.replaceFirst('PETITPAS:ACT:', '');
        final actIndex = widget.activityTypes.indexWhere((a) => a.id == actId);
        if (actIndex >= 0) {
          final atelier = widget.activityTypes[actIndex];
          final child = widget.children.where((c) => c.id == _scannedChildId).firstOrNull;
          final provider = context.read<AppStateProvider>();
          final eligibility = child == null
              ? const AtelierEligibilityResult(status: AtelierEligibility.allowed)
              : AtelierEligibilityService.evaluate(provider: provider, child: child, atelier: atelier);
          if (!eligibility.isAllowed) {
            _triggerErrorVibration();
            _showScanMessage(eligibility.message, isError: true);
          } else {
            HapticFeedback.mediumImpact();
            setState(() {
              _scannedActivityTypeId = actId;
            });
            _showScanMessage(
              eligibility.status == AtelierEligibility.allowedWithWarning
                  ? '${atelier.name} : ${eligibility.message}'
                  : 'Atelier détecté : ${atelier.name}',
              isError: false,
            );
            _checkAndAutoClose();
          }
        } else {
          _triggerErrorVibration();
          _showScanMessage('Atelier inconnu dans la base', isError: true);
        }
      } else {
        _triggerErrorVibration();
        _showScanMessage('QR Code non reconnu par A petits pas', isError: true);
      }
    }
  }

  void _checkAndAutoClose() {
    if (_scannedChildId != null && _scannedActivityTypeId != null) {
      _isClosed = true;
      Future.delayed(const Duration(milliseconds: 1200), () async {
        await _controller.stop();
        if (mounted) {
          Navigator.pop(context, {
            'childId': _scannedChildId,
            'activityTypeId': _scannedActivityTypeId,
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un identifiant pre-selectionne peut designer un eleve ou un atelier
    // supprime entre-temps : firstWhere sans repli levait alors une exception
    // en pleine construction de l'ecran.
    final scannedChild =
        widget.children.where((c) => c.id == _scannedChildId).firstOrNull;
    final scannedActivity =
        widget.activityTypes.where((a) => a.id == _scannedActivityTypeId).firstOrNull;

    final double cutOutSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Custom Cutout Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                borderColor: const Color(0xFFFF7043),
                borderWidth: 4,
                borderRadius: 24,
                cutOutSize: cutOutSize,
              ),
            ),
          ),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () async {
                    await _controller.stop();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const Text(
                  'Scanner Express',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  // Le controleur porte lui-meme l'etat (dont la lampe).
                  icon: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, state, child) => switch (state.torchState) {
                      TorchState.on =>
                        const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 24),
                      TorchState.auto =>
                        const Icon(Icons.flash_auto, color: Color(0xFFFFD54F), size: 24),
                      TorchState.unavailable =>
                        const Icon(Icons.flash_off, color: Colors.white38, size: 24),
                      TorchState.off => const Icon(Icons.flash_off, color: Colors.white, size: 24),
                    },
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),

          // Floating notification banner inside camera preview
          if (_scanMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isErrorMessage ? Colors.red.withValues(alpha: 0.9) : const Color(0xFF4E9F3D).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isErrorMessage ? Icons.error_outline : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scanMessage!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating info panel
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            scannedChild != null ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: scannedChild != null ? const Color(0xFF4E9F3D) : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scannedChild != null
                                  ? 'Élève : ${scannedChild.firstname} ${scannedChild.lastname ?? ""}'
                                  : 'Scannez le badge de l\'élève...',
                              style: TextStyle(
                                color: scannedChild != null ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: scannedChild != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            scannedActivity != null ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: scannedActivity != null ? const Color(0xFF4E9F3D) : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scannedActivity != null
                                  ? 'Atelier : ${scannedActivity.name}'
                                  : 'Scannez le QR Code de l\'atelier...',
                              style: TextStyle(
                                color: scannedActivity != null ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: scannedActivity != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          await _controller.stop();
                          if (context.mounted) {
                            Navigator.pop(context, {
                              'childId': _scannedChildId,
                              'activityTypeId': _scannedActivityTypeId,
                            });
                          }
                        },
                        child: const Text('Valider la sélection', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the transparent camera cutout and borders
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
