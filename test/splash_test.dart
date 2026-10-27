import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/widgets/splash_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Animation d'ouverture : visible au demarrage, puis s'efface.
void main() {
  testWidgets('s\'affiche puis laisse place a l\'application ; un toucher la passe', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    SplashOverlay.enabled = true;
    late AppStateProvider app;
    await tester.runAsync(() async {
      final docs = await Directory.systemTemp.createTemp('splash_');
      app = AppStateProvider(
        database: AppDatabase(fileName: 'splash_${DateTime.now().microsecondsSinceEpoch}.db'),
        documentsPath: docs.path,
        autoLoad: false,
      );
      await app.initialize();
      await app.whenStartupBackupDone();
    });

    Widget build() => ChangeNotifierProvider<AppStateProvider>.value(
          value: app,
          child: const MaterialApp(home: SplashOverlay(child: Scaffold(body: Text('APPLI')))),
        );

    await tester.pumpWidget(build());
    expect(find.text('A petits pas'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('A petits pas'), findsNothing, reason: 'l\'animation doit s\'effacer');
    expect(find.text('APPLI'), findsOneWidget);

    // Un toucher passe l'animation.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build());
    expect(find.text('A petits pas'), findsOneWidget);
    await tester.tap(find.text('A petits pas'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('A petits pas'), findsNothing);
    SplashOverlay.enabled = false;
  });
}
