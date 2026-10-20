import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/main.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/providers/cloud_sync_controller.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sync_fakes.dart';

/// Lance la vraie application (base SQLite reelle, iCloud simule) sur un
/// iPhone simule. A appeler apres avoir fixe debugDefaultTargetPlatformOverride,
/// a remettre a null avant la fin du test (exige par le framework).
///
/// [prepare] s'execute apres le chargement des donnees, avant l'affichage.
/// Terminer chaque test par [endPetitPas].
Future<(AppStateProvider, CloudSyncController)> pumpPetitPas(
  WidgetTester tester, {
  void Function(AppStateProvider app)? prepare,
}) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  // La police de test dessine chaque lettre en carre plein, bien plus large
  // que la vraie : texte reduit pour eviter des debordements sans rapport.
  tester.platformDispatcher.textScaleFactorTestValue = 0.6;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // Lecteur et enregistreur audio (notes vocales) : pas de plugin en test.
  final messenger = tester.binding.defaultBinaryMessenger;
  void silentEvents(String channel) => messenger.setMockStreamHandler(
      EventChannel(channel), MockStreamHandler.inline(onListen: (_, __) {}));
  silentEvents('xyz.luan/audioplayers.global/events');
  for (final name in ['xyz.luan/audioplayers.global', 'com.llfbandit.record/messages']) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async {
    if (call.method == 'create') {
      silentEvents('xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}');
    }
    return null;
  });

  late AppStateProvider app;
  late CloudSyncController sync;
  await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('app_');
    app = AppStateProvider(
      database: AppDatabase(fileName: 'app_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: dir.path,
      autoLoad: false,
    );
    await app.initialize();
    app.setBiometricLockEnabled(false);
    prepare?.call(app);
    sync = CloudSyncController(app, folder: FakeCloud());
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: app),
      ChangeNotifierProvider<CloudSyncController>.value(value: sync),
    ],
    child: const PetitPasApp(),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (app, sync);
}

/// Fin de test : laisse finir les ecritures en base (entrees-sorties reelles,
/// alors que l'horloge du test est simulee), arrete la synchronisation et
/// remet la plateforme par defaut. Rien ne doit survivre au test.
Future<void> endPetitPas(WidgetTester tester, CloudSyncController sync) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
  await tester.pump(const Duration(seconds: 11)); // delai de verrou sqflite
  sync.dispose();
  debugDefaultTargetPlatformOverride = null;
}
