import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/release_notes.dart';
import 'package:petitpas/models/activity_type.dart';

import 'support/app_harness.dart';

/// iPhone : barre du bas, menu « ⋯ » et Scan & Go (choix du mode puis
/// saisie manuelle enchainee).
void main() {
  testWidgets('barre du bas et menu du haut', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (_, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(kReleaseNotes.first.version);
    });

    final bar = find.byType(BottomNavigationBar);
    expect(find.descendant(of: bar, matching: find.text('Ateliers')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Badges QR')), findsNothing);
    // Plus d'acces Scan & Go ni Rapports en icone dans la barre du haut.
    expect(find.byTooltip('Scan Express'), findsNothing);
    expect(find.byTooltip('Rapports'), findsNothing);

    await tester.tap(find.byTooltip('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Badges QR élèves'), findsOneWidget);
    expect(find.text('Rapports'), findsOneWidget);
    expect(find.text('Aide'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Onglet Ateliers : entrees Espaces & Ateliers et Parcours.
    await tester.tap(find.descendant(of: bar, matching: find.text('Ateliers')));
    await tester.pumpAndSettle();
    expect(find.text('Espaces & Ateliers'), findsOneWidget);
    expect(find.text('Parcours'), findsOneWidget);

    await endPetitPas(tester, sync);
  });

  testWidgets('Scan & Go manuel : eleve par recherche, atelier par domaine', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (app, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(kReleaseNotes.first.version);
      app.addOrUpdateActivityType(ActivityType(
          id: 'tri', name: 'Tri des boutons', spaceId: app.spaces.first.id, colorHex: '#4E9F3D',
          domaineId: 'd2_maths', domaine: "L'acquisition des premiers outils mathématiques"));
    });

    await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Scan & Go')));
    await tester.pumpAndSettle();
    expect(find.text('Scanner les QR codes'), findsOneWidget);
    await tester.tap(find.text('Sélection manuelle'));
    await tester.pumpAndSettle();

    final child = app.children.first;
    final bit = child.firstname.substring(0, 2).toUpperCase();
    await tester.enterText(find.byType(TextField).first, bit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${child.firstname} ${child.lastname ?? ''}'.trim()).last);
    await tester.pumpAndSettle();

    expect(find.text('2. Quel atelier ou quelle étape ?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'mathématiques');
    await tester.pumpAndSettle();
    expect(find.text("L'acquisition des premiers outils mathématiques"), findsOneWidget);
    await tester.tap(find.text('Tri des boutons'));
    await tester.pumpAndSettle();
    expect(find.text('Valider et Enregistrer'), findsOneWidget);

    await endPetitPas(tester, sync);
  });
}
