import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/splash_pieces.dart';
import '../providers/app_provider.dart';

/// Creme de l'ecran de demarrage, identique au fond de LaunchImage.jpg et a
/// la couleur de LaunchScreen.storyboard (#FCF5E9).
const kSplashCream = Color(0xFFFCF5E9);

/// Animation d'ouverture, enchainee sur l'ecran de demarrage iOS (un fond
/// creme uni, image fixe imposee par Apple) : les petites mains peintes et
/// les feuilles se posent une a une et composent la grande empreinte, du
/// talon vers les orteils ; l'empreinte fait un petit pas, le nom apparait,
/// puis l'ecran s'efface sur l'application.
///
/// Environ 3,3 s ; un toucher la passe ; reduite a un fondu si l'appareil
/// demande moins d'animations. Elle reste affichee tant que les donnees ne
/// sont pas chargees.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  /// Coupee dans les tests d'interface (rien a voir, et pas d'attente).
  static bool enabled = true;

  /// Vrai une fois l'animation terminee (ou coupee) : le deverrouillage par
  /// Face ID l'attend pour ne pas la recouvrir.
  static final ValueNotifier<bool> done = ValueNotifier(true);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2900));
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _gone = !SplashOverlay.enabled;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gone || _started) return;
    _started = true;
    SplashOverlay.done.value = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
    _intro.addStatusListener((_) => _maybeLeave());
    _fade.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      SplashOverlay.done.value = true;
      if (mounted) setState(() => _gone = true);
    });
  }

  /// Fondu de sortie, une fois l'animation finie et les donnees chargees.
  void _maybeLeave() {
    if (!mounted || _fade.isAnimating || _fade.isCompleted) return;
    if (!_intro.isCompleted) return;
    if (!context.read<AppStateProvider>().isLoaded) return;
    _fade.forward();
  }

  @override
  void dispose() {
    SplashOverlay.done.value = true;
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    // Les donnees peuvent arriver apres la fin de l'animation.
    final loaded = context.watch<AppStateProvider>().isLoaded;
    if (loaded) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLeave());

    return Stack(children: [
      widget.child,
      FadeTransition(
        opacity: ReverseAnimation(_fade),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _intro.value = 1;
            _maybeLeave();
          },
          child: ColoredBox(
            color: kSplashCream,
            child: LayoutBuilder(builder: (context, c) {
              final side = c.biggest.shortestSide;
              final footH = side * 0.842;
              return AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  final t = _intro.value;
                  // 1. Les mains et les feuilles se posent une a une, comme
                  //    des tampons, du talon vers les orteils (0.03 -> 0.66).
                  // 2. L'empreinte entiere fait un petit pas (0.68 -> 0.86).
                  // 3. Le nom apparait (0.72 -> 0.9).
                  const first = 0.03, spread = 0.52, each = 0.11;
                  final n = kSplashPieces.length;
                  final footW = footH * kSplashFootW / kSplashFootH;
                  final k = footH / kSplashFootH;
                  final lift = t < 0.68
                      ? 0.0
                      : t < 0.75
                          ? Curves.easeOut.transform((t - 0.68) / 0.07)
                          : 1 - Curves.bounceOut.transform(((t - 0.75) / 0.11).clamp(0.0, 1.0));
                  final dy = -side * 0.03 * lift;
                  final scale = 1 + 0.035 * lift;
                  final title = Curves.easeOut.transform(((t - 0.72) / 0.18).clamp(0.0, 1.0));
                  return Stack(children: [
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: footW,
                            height: footH,
                            child: Stack(clipBehavior: Clip.none, children: [
                              for (final (i, (asset, x, y, w, h)) in kSplashPieces.indexed)
                                () {
                                  final start = first + spread * (n <= 1 ? 0 : i / (n - 1));
                                  final p = ((t - start) / each).clamp(0.0, 1.0);
                                  if (p == 0) return const SizedBox.shrink();
                                  // Tampon : arrive un peu plus grand et se pose.
                                  final stamp = 1.35 - 0.35 * Curves.easeOutBack.transform(p);
                                  return Positioned(
                                    left: x * k,
                                    top: y * k,
                                    width: w * k,
                                    height: h * k,
                                    child: Opacity(
                                      opacity: Curves.easeOut.transform(p),
                                      child: Transform.scale(
                                        scale: stamp,
                                        child: Image.asset(asset, fit: BoxFit.fill),
                                      ),
                                    ),
                                  );
                                }(),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      // Sous l'empreinte ; en paysage (empreinte presque aussi haute que
                      // l'ecran), en bas de l'ecran.
                      top: ((c.maxHeight / 2 + footH / 2 + 12).clamp(0.0, c.maxHeight - 56)) + 10 * (1 - title),
                      child: Opacity(
                        opacity: title,
                        child: const Text(
                          'A petits pas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B4A2E),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              );
            }),
          ),
        ),
      ),
    ]);
  }
}
