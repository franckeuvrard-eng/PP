import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/release_notes.dart';

import 'support/app_harness.dart';

/// Tirer vers le bas sur l'accueil (iPhone) lance la synchronisation iCloud,
/// meme quand l'accueil tient sur un seul ecran.
void main() {
  testWidgets('tirer pour actualiser sur l\'accueil synchronise', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (_, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(kReleaseNotes.first.version);
    });

    await tester.fling(find.text("Fil d'actualité du jour"), const Offset(0, 400), 1500);
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsOneWidget, reason: 'indicateur absent');
    var started = false;
    for (var i = 0; i < 10 && !started; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      started = sync.syncing;
    }
    expect(started, isTrue, reason: 'le geste ne lance pas la synchronisation');
    // Laisse la synchro (entrees-sorties reelles) se terminer.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 1));

    await endPetitPas(tester, sync);
  });
}
