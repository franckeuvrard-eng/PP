import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/release_notes.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/services/icloud_sync.dart';

import 'support/app_harness.dart';
import 'support/sync_fakes.dart';

/// Quand la synchro automatique doit supprimer beaucoup d'elements, une
/// fenetre previent l'utilisateur au lieu d'attendre en silence.
void main() {
  testWidgets('suppressions massives en attente : fenetre « Synchronisation en attente »',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final cloud = FakeCloud();
    final (app, sync) = await pumpPetitPas(tester, cloud: cloud, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(kReleaseNotes.first.version);
      for (var i = 0; i < 10; i++) {
        app.addOrUpdateChild(
            Child(id: 'e$i', firstname: 'Élève $i', colorHex: '#4E9F3D', avatarText: 'E'));
      }
    });

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300)); // ecritures en base
      expect((await sync.refreshNow())!.status,
          anyOf(CloudSyncStatus.synced, CloudSyncStatus.upToDate));
      // Un autre appareil vide la classe dans iCloud (avec son accord).
      final mac = FakeHost('mac', snap([]));
      await CloudSync(mac, cloud).sync();
      mac.data = snap([]);
      await CloudSync(mac, cloud).sync(confirmChanges: (_) async => true);
    });

    await tester.runAsync(() async => sync.refreshNow());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Synchronisation en attente'), findsOneWidget);
    expect(app.children.where((c) => c.id.startsWith('e')), hasLength(10),
        reason: 'rien n\'est supprime sans accord');

    await tester.tap(find.text('Plus tard'));
    await tester.pump(const Duration(milliseconds: 300));
    await endPetitPas(tester, sync);
  });
}
