import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/widgets/parcours_table.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tableau d'un parcours : eleves en lignes, une case par etape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<AppStateProvider> newApp() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('tableau_');
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'tableau_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: dir.path,
      autoLoad: false,
    );
    await app.initialize();
    app.setSections(['PS', 'MS']);
    // Une base neuve est semee avec une classe d'exemple : on part d'une classe vide.
    for (final c in app.children.toList()) {
      app.deleteChild(c.id);
    }
    for (final (id, name) in [('lea', 'Léa'), ('tom', 'Tom'), ('ana', 'Ana')]) {
      app.addOrUpdateChild(Child(id: id, firstname: name, group: 'MS', colorHex: '#4E9F3D', avatarText: name[0]));
    }
    app.saveProgression(Progression(
        id: 'p', name: 'Découpage', colorHex: '#42A5F5', minStatusId: app.evaluationStatuses.last.id));
    for (final id in ['e1', 'e2', 'e3', 'e4']) {
      app.addOrUpdateActivityType(ActivityType(
          id: id,
          name: 'Étape $id',
          spaceId: '',
          progressionId: 'p',
          colorHex: '#42A5F5',
          position: app.nextPositionInProgression('p')));
    }
    return app;
  }

  List<ParcoursCell> states(AppStateProvider app, String childId) => ParcoursTable.statesFor(
      app, app.progressionById('p')!, app.ateliersInProgressionOrdered('p'), app.childById(childId)!);

  /// Laisse finir les ecritures en base puis les minuteurs de verrou sqflite.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(seconds: 11));
  }

  Future<void> pumpTable(WidgetTester tester, AppStateProvider app) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ParcoursTable(progression: app.progressionById('p')!),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  test('etats des cases : premiere etape ouverte, la suite verrouillee', () async {
    final app = await newApp();
    expect(states(app, 'lea'),
        [ParcoursCell.open, ParcoursCell.locked, ParcoursCell.locked, ParcoursCell.locked]);

    app.logActivityForChildren(
        childIds: ['lea'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);
    expect(states(app, 'lea'),
        [ParcoursCell.validated, ParcoursCell.open, ParcoursCell.locked, ParcoursCell.locked]);
  });

  test('un depart en cours de parcours : etapes avant = non demandees', () async {
    final app = await newApp();
    app.setParcoursStart(childIds: ['tom'], progressionId: 'p', atelierId: 'e3');
    expect(states(app, 'tom'),
        [ParcoursCell.skipped, ParcoursCell.skipped, ParcoursCell.open, ParcoursCell.locked]);
  });

  testWidgets('cocher une case enregistre au seuil, la retoucher annule sans trace', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('cell_lea_e1')));
    await tester.pump();
    final logs = app.activitiesForChild('lea');
    expect(logs, hasLength(1));
    expect(logs.single.activityTypeId, 'e1');
    expect(logs.single.evaluationStatusId, app.evaluationStatuses.last.id);
    expect(states(app, 'lea').first, ParcoursCell.validated);
    // Les autres eleves ne sont pas touches.
    expect(app.activitiesForChild('tom'), isEmpty);
    // Une case seule n'affiche aucune banniere (elle gene quand on en valide beaucoup).
    expect(find.text('Annuler'), findsNothing);

    // Retoucher la case la retire : l'observation est supprimee, pas de niveau bas ajoute.
    await tester.tap(find.byKey(const Key('cell_lea_e1')));
    await tester.pump();
    expect(app.activitiesForChild('lea'), isEmpty);
    expect(states(app, 'lea').first, ParcoursCell.open);

    await settle(tester);
  });

  testWidgets('valider beaucoup de cases d\'affilee : aucune banniere', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    await pumpTable(tester, app);

    for (final id in ['lea', 'tom', 'ana']) {
      await tester.tap(find.byKey(Key('cell_${id}_e1')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SnackBar), findsNothing);
    for (final id in ['lea', 'tom', 'ana']) {
      expect(states(app, id).first, ParcoursCell.validated, reason: id);
    }

    await settle(tester);
  });

  testWidgets('la banniere d\'une action en masse disparait toute seule', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('col_e1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Valider pour 3 élève(s)'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Annuler'), findsOneWidget);

    // Avec une action, Flutter garderait la banniere indefiniment (persist).
    // Le compte a rebours demarre une fois la banniere entierement affichee.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Annuler'), findsNothing);

    await settle(tester);
  });

  testWidgets('decocher ajoute un niveau bas sans supprimer l\'historique', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    app.logActivityForChildren(
        childIds: ['lea'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id, note: 'bravo');
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('cell_lea_e1')));
    await tester.pump();

    final logs = app.activitiesForChild('lea');
    expect(logs, hasLength(2), reason: 'l\'observation d\'origine est conservee');
    expect(logs.any((l) => l.note == 'bravo'), isTrue);
    expect(states(app, 'lea').first, ParcoursCell.open);

    // « Annuler » : la validation revient.
    await tester.pump(const Duration(milliseconds: 600)); // bannière affichée
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(app.activitiesForChild('lea'), hasLength(1));
    expect(states(app, 'lea').first, ParcoursCell.validated);

    await settle(tester);
  });

  testWidgets('une case verrouillee ou non demandee ne change rien', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    app.setParcoursStart(childIds: ['tom'], progressionId: 'p', atelierId: 'e3');
    // La base neuve contient des observations d'exemple : on compte la difference.
    final before = app.activities.length;
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('cell_lea_e3'))); // verrouillee
    await tester.pump();
    expect(find.textContaining('Verrouillée : validez d\'abord'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cell_tom_e1'))); // non demandee
    await tester.pump();
    expect(find.textContaining('Non demandée : Tom'), findsOneWidget);

    expect(app.activities.length, before);
    await settle(tester);
  });

  testWidgets('colonne : valider pour tous les eleves eligibles', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    // Ana a deja l'etape 1 : elle n'est plus eligible a la colonne 1.
    app.logActivityForChildren(
        childIds: ['ana'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('col_e1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider pour 2 élève(s) éligible(s)'));
    await tester.pump();

    for (final id in ['lea', 'tom', 'ana']) {
      expect(states(app, id).first, ParcoursCell.validated, reason: id);
    }
    // Ana n'a pas ete revalidee : une seule observation.
    expect(app.activitiesForChild('ana'), hasLength(1));
    expect(app.activitiesForChild('lea'), hasLength(1));

    // « Annuler » ne retire que ce geste.
    await tester.pump(const Duration(milliseconds: 600)); // bannière affichée
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(app.activitiesForChild('lea'), isEmpty);
    expect(app.activitiesForChild('ana'), hasLength(1));

    await settle(tester);
  });

  testWidgets('ligne : valider toutes les etapes jusqu\'a l\'etape 3', (tester) async {
    final app = (await tester.runAsync(newApp))!;
    await pumpTable(tester, app);

    await tester.tap(find.byKey(const Key('row_lea')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Valider jusqu\'à l\'étape 3'));
    await tester.pump();

    expect(states(app, 'lea'),
        [ParcoursCell.validated, ParcoursCell.validated, ParcoursCell.validated, ParcoursCell.open]);
    final logs = app.activitiesForChild('lea');
    expect(logs.map((l) => l.activityTypeId).toSet(), {'e1', 'e2', 'e3'});
    expect(logs.map((l) => l.id).toSet().length, 3, reason: 'un identifiant par etape');
    expect(app.activitiesForChild('tom'), isEmpty);

    await settle(tester);
  });
}
