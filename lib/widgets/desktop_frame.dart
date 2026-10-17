import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Largeur a partir de laquelle on bascule sur la mise en page ordinateur
/// (barre laterale a la place de la barre d'onglets du bas).
const double kDesktopBreakpoint = 840;

/// Largeur maximale du contenu : au-dela, les listes et formulaires pensees
/// pour un telephone deviennent illisibles (lignes de 1500 px).
const double kDesktopContentMaxWidth = 1100;

/// Comportement de defilement pour la souris et le trackpad : glisser avec la
/// souris fait defiler (le comportement par defaut du bureau ne le permet
/// pas), et la barre de defilement reste visible.
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

/// Une destination de la navigation principale.
class DesktopDestination {
  const DesktopDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Mise en page ordinateur : barre laterale a gauche, contenu centre a droite.
///
/// Ne connait pas les ecrans : [body] est fourni par l'appelant, pour que les
/// versions mobile et ordinateur partagent exactement les memes pages.
class DesktopFrame extends StatelessWidget {
  const DesktopFrame({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    required this.className,
    required this.onHelp,
    required this.body,
  });

  final List<DesktopDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final String className;
  final VoidCallback onHelp;
  final Widget body;

  static const _green = Color(0xFF4E9F3D);
  static const double _railWidth = 240;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: _railWidth,
            selectedIndex: currentIndex,
            onDestinationSelected: onSelected,
            backgroundColor: theme.cardColor,
            indicatorColor: _green.withValues(alpha: 0.15),
            selectedIconTheme: const IconThemeData(color: _green),
            selectedLabelTextStyle: const TextStyle(
                color: _green, fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14),
            // Largeur fixe : le rail donne a `leading` une largeur non bornee,
            // incompatible avec l'Expanded du titre.
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: SizedBox(
                width: _railWidth - 32,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.child_care,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('A petits pas',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            className,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: _green,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: onHelp,
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: const Text('Aide'),
                  ),
                ),
              ),
            ),
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationRailDestination(
                  icon: Icon(destinations[i].icon),
                  selectedIcon: Icon(destinations[i].selectedIcon),
                  label: Text(destinations[i].label),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kDesktopContentMaxWidth),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourcis clavier de navigation (Cmd+1..9 sur Mac, Ctrl+1..9 ailleurs).
///
/// Sur macOS, les memes raccourcis sont declares dans la barre de menus
/// systeme ([PlatformMenuBar]) : on ne les double pas ici, sinon la barre de
/// menus et le widget se disputeraient la touche.
Map<ShortcutActivator, VoidCallback> desktopNavigationShortcuts(
  int count,
  ValueChanged<int> onSelected,
) {
  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  return {
    for (var i = 0; i < count && i < digits.length; i++)
      SingleActivator(digits[i], control: true): () => onSelected(i),
  };
}
