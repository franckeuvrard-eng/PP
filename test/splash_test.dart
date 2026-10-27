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
          child: const MaterialApp(home: SplashOverlay(child: _Counted())),
        );

    await tester.pumpWidget(build());
    expect(find.text('A petits pas'), findsOneWidget);
    // Face ID attend : l'animation n'est pas finie.
    await tester.pump(const Duration(seconds: 1));
    expect(SplashOverlay.done.value, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('A petits pas'), findsNothing, reason: 'l\'animation doit s\'effacer');
    expect(find.text('APPLI'), findsOneWidget);
    expect(SplashOverlay.done.value, isTrue, reason: 'Face ID peut alors se lancer');
    // L'ecran sous l'animation n'est pas reconstruit a la fin : sinon le
    // verrouillage redemandait Face ID une seconde fois.
    expect(_Counted.created, 1);

    // Un toucher passe l'animation.
    await tester.pumpWidget(const SizedBox());
    _Counted.created = 0;
    await tester.pumpWidget(build());
    expect(find.text('A petits pas'), findsOneWidget);
    await tester.tap(find.text('A petits pas'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('A petits pas'), findsNothing);
    SplashOverlay.enabled = false;
  });
}

/// Ecran factice qui compte ses creations (un etat recree = Face ID redemande).
class _Counted extends StatefulWidget {
  const _Counted();
  static int created = 0;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    _Counted.created++;
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('APPLI'));
}
