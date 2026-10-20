import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/main.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/providers/cloud_sync_controller.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sync_fakes.dart';

/// Tirer vers le bas sur l'accueil (iPhone) lance la synchronisation iCloud.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('tirer pour actualiser sur l\'accueil synchronise', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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

    final cloud = FakeCloud();
    late AppStateProvider app;
    late CloudSyncController sync;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('ptr_');
      app = AppStateProvider(
        database: AppDatabase(fileName: 'ptr_${DateTime.now().microsecondsSinceEpoch}.db'),
        documentsPath: dir.path,
        autoLoad: false,
      );
      await app.initialize();
      app.setBiometricLockEnabled(false);
      sync = CloudSyncController(app, folder: cloud);
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

    sync.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
