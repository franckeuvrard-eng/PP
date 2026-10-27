import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Creme de l'ecran de demarrage, identique au fond de LaunchImage.jpg et a
/// la couleur de LaunchScreen.storyboard (#FCF5E9).
const kSplashCream = Color(0xFFFCF5E9);

/// Animation d'ouverture, enchainee sur l'ecran de demarrage iOS (une image
/// fixe imposee par Apple) : l'empreinte part exactement de la meme place,
/// fait un petit « pas » (elle se souleve et rebondit), le nom apparait,
/// puis l'ecran s'efface sur l'application.
///
/// Environ 1,5 s ; un toucher la passe ; reduite a un fondu si l'appareil
/// demande moins d'animations. Elle reste affichee tant que les donnees ne
/// sont pas chargees.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  /// Coupee dans les tests d'interface (rien a voir, et pas d'attente).
  static bool enabled = true;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _gone = !SplashOverlay.enabled;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gone || _started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
    _intro.addStatusListener((_) => _maybeLeave());
    _fade.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _gone = true);
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
                  // Le pas : monte (0 -> 0.35) puis retombe en rebondissant
                  // (0.35 -> 0.62).
                  final lift = t < 0.35
                      ? Curves.easeOut.transform(t / 0.35)
                      : 1 - Curves.bounceOut.transform(((t - 0.35) / 0.27).clamp(0.0, 1.0));
                  final dy = -side * 0.035 * lift;
                  final scale = 1 + 0.04 * lift;
                  // Le nom : fondu et petite montee (0.3 -> 0.75).
                  final title = Curves.easeOut.transform(((t - 0.3) / 0.45).clamp(0.0, 1.0));
                  return Stack(children: [
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            height: footH,
                            child: Image.asset('assets/images/splash_foot.png', fit: BoxFit.contain),
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
