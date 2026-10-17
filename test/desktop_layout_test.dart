import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:petitpas/main.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';

/// Parcourt les pages principales dans une fenetre d'ordinateur : une page
/// pensee pour un telephone ne doit pas deborder ni lever d'exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final taille in const [Size(1280, 800), Size(900, 640)]) {
    testWidgets('barre laterale et pages principales a ${taille.width.toInt()}x${taille.height.toInt()}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Toute E/S reelle (dossier temporaire, SQLite) doit passer par
      // runAsync : la zone de testWidgets ne fait pas avancer les vrais futures.
      final provider = await tester.runAsync(() async {
        final racine = await Directory.systemTemp.createTemp('petitpas_desktop_');
        final p = AppStateProvider(
          database: AppDatabase(
              fileName: 'petitpas_desktop_${DateTime.now().microsecondsSinceEpoch}.db'),
          documentsPath: racine.path,
          autoLoad: false,
        );
        await p.initialize();
        return p;
      });

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider!,
        child: const MaterialApp(home: MainNavigationFrame()),
      ));
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);

      for (final page in ['Élèves', 'Badges QR', 'Paramètres', 'Scan & Go', 'Accueil']) {
        await tester.tap(find.descendant(
            of: find.byType(NavigationRail), matching: find.text(page)));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'page $page');
      }
    });
  }
}
