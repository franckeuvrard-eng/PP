import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/seed_ids.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/providers/cloud_sync_controller.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/icloud_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sync_fakes.dart';

/// Synchronisation iCloud automatique, avec la vraie application (base
/// SQLite) et un iCloud simule partage par deux « appareils ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory racine;
  late FakeCloud cloud;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    racine = await Directory.systemTemp.createTemp('petitpas_cloud_');
    cloud = FakeCloud();
    // iCloud n'est actif que sur les plateformes Apple.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<(AppStateProvider, CloudSyncController)> appareil(String nom) async {
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'cloud_${nom}_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: (await Directory('${racine.path}/$nom').create()).path,
      autoLoad: false,
    );
    await app.initialize();
    final controller = CloudSyncController(app, folder: cloud);
    addTearDown(controller.dispose);
    return (app, controller);
  }

  Future<void> attendre(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  test('tirer pour actualiser recupere aussitot les changements', () async {
    final (mac, macSync) = await appareil('mac');
    final (phone, phoneSync) = await appareil('phone');
    await attendre(() => !macSync.syncing && !phoneSync.syncing);

    mac.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
    // Deja envoyee par la synchro automatique declenchee par la modification,
    // ou envoyee maintenant : dans les deux cas, c'est dans iCloud.
    expect((await macSync.refreshNow())!.status,
        anyOf(CloudSyncStatus.synced, CloudSyncStatus.upToDate));

    final outcome = await phoneSync.refreshNow();
    expect(outcome!.status, CloudSyncStatus.synced);
    expect(phone.children.any((c) => c.id == 'lea'), isTrue);
  });

  test('une nouvelle version signalee par iCloud est synchronisee sans attendre', () async {
    final (mac, macSync) = await appareil('mac');
    final (phone, phoneSync) = await appareil('phone');
    await macSync.refreshNow();
    await phoneSync.refreshNow(); // l'iPhone ecoute desormais iCloud

    mac.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', colorHex: '#4E9F3D', avatarText: 'T'));
    await macSync.refreshNow();
    cloud.changesController.add(null); // iCloud previent l'iPhone

    await attendre(() => phone.children.any((c) => c.id == 'tom'));
    expect(phone.children.any((c) => c.id == 'tom'), isTrue);
  });

  test("les identifiants d'exemple suivent les exemples de l'installation", () async {
    final (app, _) = await appareil('neuf');
    expect(app.children.map((c) => c.id).toSet(), kSeedChildIds);
    expect(app.activities.map((a) => a.id).toSet(), kSeedActivityIds);
  });
}
