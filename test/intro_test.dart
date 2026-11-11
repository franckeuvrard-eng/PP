import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/release_notes.dart';
import 'package:petitpas/models/child.dart';

import 'support/app_harness.dart';

/// Ecrans d'accueil au lancement : prise en main au premier lancement,
/// nouveautes une fois apres une mise a jour, rien ensuite.
void main() {
  final latest = kReleaseNotes.first.version;

  testWidgets('premier lancement : prise en main, puis plus rien', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (app, sync) = await pumpPetitPas(tester);
    expect(find.text('Bienvenue dans A petits pas'), findsOneWidget);
    expect(find.text('Nouveautés'), findsNothing);
    expect(app.onboardingDone, isTrue);
    expect(app.releaseNotesSeen, latest, reason: 'pas de nouveautes en plus de la visite');

    // « Passer » mene directement a la liste de parametrage.
    await tester.tap(find.text('Passer'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Paramétrez votre classe'), findsOneWidget);
    await endPetitPas(tester, sync);
  });

  testWidgets('mise a jour d\'une classe deja utilisee : nouveautes, pas de visite', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (app, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.addOrUpdateChild(
          Child(id: 'vraie', firstname: 'Inès', colorHex: '#4E9F3D', avatarText: 'I'));
    });
    expect(find.text('Bienvenue dans A petits pas'), findsNothing);
    expect(find.text('Nouveautés'), findsOneWidget);
    expect(app.releaseNotesSeen, latest);
    await endPetitPas(tester, sync);
  });

  testWidgets('deja a jour : aucun ecran par-dessus l\'accueil', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (_, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(latest);
    });
    expect(find.text('Bienvenue dans A petits pas'), findsNothing);
    expect(find.text('Nouveautés'), findsNothing);
    expect(find.text("Fil d'actualité du jour"), findsOneWidget);
    await endPetitPas(tester, sync);
  });
}
