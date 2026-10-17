import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/widgets/desktop_frame.dart';

void main() {
  group('DesktopFrame', () {
    testWidgets('barre laterale : choix d\'une destination a la souris', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selected = 0;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => DesktopFrame(
            destinations: const [
              DesktopDestination(label: 'Accueil', icon: Icons.home, selectedIcon: Icons.home),
              DesktopDestination(label: 'Élèves', icon: Icons.people, selectedIcon: Icons.people),
            ],
            currentIndex: selected,
            onSelected: (i) => setState(() => selected = i),
            className: 'PS',
            onHelp: () {},
            body: Text('page $selected'),
          ),
        ),
      ));
      expect(find.text('page 0'), findsOneWidget);
      await tester.tap(find.text('Élèves'));
      await tester.pump();
      expect(find.text('page 1'), findsOneWidget);
    });
  });
}
