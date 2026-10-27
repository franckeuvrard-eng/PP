import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../services/atelier_eligibility_service.dart';
import '../utils/app_icons.dart';
import '../utils/color_utils.dart';
import '../utils/platform_support.dart';
import 'qr_scanner_screen.dart';

/// Mode eleve (tablette) : l'enfant note lui-meme ce qu'il a fait. Il choisit
/// sa photo (ou scanne son badge) puis l'atelier ; l'observation part « a
/// valider », sans niveau, et l'adulte la valide ensuite. La sortie du mode
/// demande Face ID / le code de l'appareil.
class StudentModeScreen extends StatefulWidget {
  const StudentModeScreen({super.key});

  @override
  State<StudentModeScreen> createState() => _StudentModeScreenState();
}

class _StudentModeScreenState extends State<StudentModeScreen> {
  Child? _child;
  String? _doneAtelierName;
  Timer? _reset;

  static const _cream = Color(0xFFFCF5E9);

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _exit() async {
    var ok = false;
    try {
      final auth = LocalAuthentication();
      if (await auth.isDeviceSupported()) {
        ok = await auth.authenticate(
          localizedReason: 'Réservé à l\'adulte : quitter le mode élève.',
          biometricOnly: false,
        );
      } else {
        ok = await _confirmWithoutAuth();
      }
    } on PlatformException {
      ok = await _confirmWithoutAuth();
    } on MissingPluginException {
      ok = await _confirmWithoutAuth();
    } catch (_) {
      ok = false;
    }
    if (ok && mounted) Navigator.of(context).pop();
  }

  /// Appareil sans code ni Face ID : simple confirmation.
  Future<bool> _confirmWithoutAuth() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quitter le mode élève ?'),
          content: const Text('Cet appareil n\'a pas de code : la sortie n\'est pas protégée.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rester')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
          ],
        ),
      ) ??
      false;

  void _record(AppStateProvider app, ActivityType atelier) {
    final child = _child!;
    final now = DateTime.now();
    app.logActivity(ActivityLog(
      id: 'log_${now.millisecondsSinceEpoch}_${child.id}',
      childId: child.id,
      activityTypeId: atelier.id,
      timestamp: now,
      pendingValidation: true,
    ));
    HapticFeedback.mediumImpact();
    setState(() => _doneAtelierName = atelier.name);
    _reset = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _child = null;
          _doneAtelierName = null;
        });
      }
    });
  }

  Future<void> _scan(AppStateProvider app) async {
    final result = await Navigator.push<Map<String, String?>>(
      context,
      MaterialPageRoute(
        builder: (_) => QrCameraScannerOverlay(children: app.children, activityTypes: app.activityTypes),
      ),
    );
    if (result == null || !mounted) return;
    final child = app.childById(result['childId']);
    final atelier = app.activityTypeById(result['activityTypeId']);
    if (child != null) setState(() => _child = child);
    if (child != null && atelier != null && _allowed(app, child, atelier)) _record(app, atelier);
  }

  bool _allowed(AppStateProvider app, Child c, ActivityType a) =>
      AtelierEligibilityService.evaluate(provider: app, child: c, atelier: a).isAllowed;

  Widget _photo(AppStateProvider app, String? relPath, {required Widget fallback}) {
    final abs = app.getAbsolutePath(relPath);
    if (abs != null && File(abs).existsSync()) {
      return Image.file(File(abs), fit: BoxFit.cover);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppStateProvider>(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                if (_child != null && _doneAtelierName == null)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Ce n\'est pas moi'),
                    onPressed: () => setState(() => _child = null),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Adulte'),
                  onPressed: _exit,
                ),
              ]),
            ),
            Expanded(
              child: _doneAtelierName != null
                  ? _bravo()
                  : _child == null
                      ? _whoAmI(app)
                      : _whatDidIDo(app, _child!),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bravo() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 120, color: Color(0xFF4E9F3D)),
          const SizedBox(height: 16),
          Text('Bravo ${_child?.firstname ?? ''} !',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_doneAtelierName!, style: const TextStyle(fontSize: 26)),
        ]),
      );

  Widget _whoAmI(AppStateProvider app) {
    final children = app.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    return Column(children: [
      const Text('Qui es-tu ?', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
      if (isMobilePlatform)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner mon badge', style: TextStyle(fontSize: 18)),
            onPressed: () => _scan(app),
          ),
        ),
      const SizedBox(height: 12),
      Expanded(
        child: GridView.extent(
          maxCrossAxisExtent: 170,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.82,
          children: [
            for (final c in children)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _child = c),
                  child: Column(children: [
                    Expanded(
                      child: SizedBox.expand(
                        child: _photo(app, c.imagePath,
                            fallback: Container(
                              color: hexToColor(c.colorHex),
                              alignment: Alignment.center,
                              child: Text(c.avatarText.isNotEmpty ? c.avatarText : c.firstname.characters.first,
                                  style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold)),
                            )),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(c.firstname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _whatDidIDo(AppStateProvider app, Child child) {
    final planned = app.plannedAteliersFor(child, DateTime.now());
    final all = app.activityTypes.where((a) => _allowed(app, child, a)).toList()
      ..sort((a, b) {
        // Ce qui est prevu aujourd'hui d'abord.
        final pa = planned.contains(a.id) ? 0 : 1, pb = planned.contains(b.id) ? 0 : 1;
        return pa != pb ? pa.compareTo(pb) : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return Column(children: [
      Text('${child.firstname}, qu\'as-tu fait ?',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
      if (isMobilePlatform)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner l\'atelier', style: TextStyle(fontSize: 18)),
            onPressed: () => _scan(app),
          ),
        ),
      const SizedBox(height: 12),
      Expanded(
        child: GridView.extent(
          maxCrossAxisExtent: 220,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            for (final a in all)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _record(app, a),
                  child: Column(children: [
                    Expanded(
                      child: SizedBox.expand(
                        child: _photo(app, a.allPhotoPaths.isEmpty ? null : a.allPhotoPaths.first,
                            fallback: Container(
                              color: hexToColor(a.colorHex),
                              alignment: Alignment.center,
                              child: Icon(iconForName(a.iconName, fallback: Icons.palette), size: 64, color: Colors.white),
                            )),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        if (planned.contains(a.id))
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star, color: Color(0xFFE8833A), size: 20),
                          ),
                        Expanded(
                          child: Text(a.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}
