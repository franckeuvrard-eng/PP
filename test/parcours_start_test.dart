import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/screens/bulk_validation_screen.dart';
import 'package:petitpas/screens/parcours_start_screen.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/atelier_eligibility_service.dart';
import 'package:petitpas/services/mandatory_ateliers_pdf_service.dart';
import 'package:petitpas/services/parcours_progress.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Validation groupee et depart en cours de parcours.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<AppStateProvider> newApp() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('depart_');
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'depart_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: dir.path,
      autoLoad: false,
    );
    await app.initialize();
    app.setSections(['PS', 'MS']);
    // Une base neuve est semee avec une classe d'exemple : on part d'une classe vide.
    for (final c in app.children.toList()) {
      app.deleteChild(c.id);
    }
    for (final (id, name, group) in [
      ('lea', 'Léa', 'MS'),
      ('tom', 'Tom', 'MS'),
      ('ana', 'Ana', 'PS'),
    ]) {
      app.addOrUpdateChild(
          Child(id: id, firstname: name, group: group, colorHex: '#4E9F3D', avatarText: name[0]));
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

  group('depart en cours de parcours', () {
    test('sans depart : le verrou et la position sont ceux du debut', () async {
      final app = await newApp();
      final steps = app.ateliersInProgressionOrdered('p');
      final lea = app.childById('lea')!;
      expect(ParcoursProgress.of(provider: app, parcours: app.progressionById('p')!, steps: steps, childId: 'lea').step, 0);
      final r = AtelierEligibilityService.evaluate(
          provider: app, child: lea, atelier: app.activityTypeById('e3')!);
      expect(r.status, AtelierEligibility.blockedProgression);
      expect(r.missingPrerequisites.map((a) => a.id), ['e1', 'e2']);
    });

    test('un groupe demarre a l\'etape 3 : plus de verrou avant, pas de retard', () async {
      final app = await newApp();
      final changed = app.setParcoursStart(childIds: ['lea', 'tom'], progressionId: 'p', atelierId: 'e3');
      expect(changed, 2);

      final steps = app.ateliersInProgressionOrdered('p');
      final p = app.progressionById('p')!;
      final lea = app.childById('lea')!;

      // Position : l'etape 3 (rang 2), les deux premieres comptent comme franchies.
      final pos = ParcoursProgress.of(provider: app, parcours: p, steps: steps, childId: 'lea');
      expect(pos.step, 2);
      expect(pos.current!.id, 'e3');

      // L'etape 3 est ouverte, la 4 reste verrouillee par la 3 seulement.
      expect(AtelierEligibilityService.evaluate(provider: app, child: lea, atelier: app.activityTypeById('e3')!).isAllowed, isTrue);
      final e4 = AtelierEligibilityService.evaluate(provider: app, child: lea, atelier: app.activityTypeById('e4')!);
      expect(e4.status, AtelierEligibility.blockedProgression);
      expect(e4.missingPrerequisites.map((a) => a.id), ['e3']);

      // Les etapes avant le depart restent accessibles (non demandees).
      expect(AtelierEligibilityService.evaluate(provider: app, child: lea, atelier: app.activityTypeById('e1')!).isAllowed, isTrue);

      // Aucune observation inventee pour les etapes sautees.
      expect(app.activitiesForChild('lea'), isEmpty);

      // Les autres eleves ne sont pas touches.
      expect(app.childById('ana')!.parcoursStarts, isEmpty);
      expect(ParcoursProgress.of(provider: app, parcours: p, steps: steps, childId: 'ana').step, 0);
    });

    test('valider l\'etape de depart fait avancer l\'eleve', () async {
      final app = await newApp();
      app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: 'e3');
      app.logActivityForChildren(
          childIds: ['lea'], activityTypeId: 'e3', evaluationStatusId: app.evaluationStatuses.last.id);
      final pos = ParcoursProgress.of(
          provider: app,
          parcours: app.progressionById('p')!,
          steps: app.ateliersInProgressionOrdered('p'),
          childId: 'lea');
      expect(pos.step, 3);
      expect(pos.current!.id, 'e4');
    });

    test('remettre au debut, et depart sur une etape supprimee', () async {
      final app = await newApp();
      app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: 'e3');
      expect(app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: null), 1);
      expect(app.childById('lea')!.parcoursStarts, isEmpty);
      // Deja au debut : rien a changer.
      expect(app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: null), 0);

      app.setParcoursStart(childIds: ['tom'], progressionId: 'p', atelierId: 'e3');
      app.deleteActivityType('e3');
      final steps = app.ateliersInProgressionOrdered('p');
      // Etape de depart disparue : on propose tout plutot que de cacher des etapes.
      expect(ParcoursProgress.of(provider: app, parcours: app.progressionById('p')!, steps: steps, childId: 'tom').step, 0);
    });

    test('le depart survit a la sauvegarde / synchro (Child.toMap)', () async {
      final app = await newApp();
      app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: 'e2');
      final copy = Child.fromMap(app.childById('lea')!.toMap());
      expect(copy.parcoursStarts, {'p': 'e2'});
      // Une fiche sans depart reste identique a celle des versions precedentes.
      expect(app.childById('ana')!.toMap().containsKey('parcoursStarts'), isFalse);
      expect(Child.fromMap(app.childById('ana')!.toMap()).parcoursStarts, isEmpty);
    });

    test('le plan de travail des parcours n\'imprime pas les etapes avant le depart', () async {
      final app = await newApp();
      final avant = await MandatoryAteliersPdfService.buildParcoursBytes(
          provider: app, children: [app.childById('lea')!], format: PdfPageFormat.a4);
      app.setParcoursStart(childIds: ['lea'], progressionId: 'p', atelierId: 'e4');
      final apres = await MandatoryAteliersPdfService.buildParcoursBytes(
          provider: app, children: [app.childById('lea')!], format: PdfPageFormat.a4);
      // 4 etapes puis 1 seule : le document est plus petit.
      expect(apres.length, lessThan(avant.length));
    });
  });

  group('validation groupee', () {
    test('une observation par eleve, sans toucher aux autres', () async {
      final app = await newApp();
      final acquis = app.evaluationStatuses.last.id;
      final created = app.logActivityForChildren(
          childIds: ['lea', 'tom', 'lea', 'inconnu'],
          activityTypeId: 'e1',
          evaluationStatusId: acquis,
          note: '  fait en atelier  ');
      // Doublon et eleve inconnu ecartes.
      expect(created.length, 2);
      expect(created.map((l) => l.id).toSet().length, 2);
      expect(app.activitiesForChild('lea').single.evaluationStatusId, acquis);
      expect(app.activitiesForChild('lea').single.note, 'fait en atelier');
      expect(app.activitiesForChild('ana'), isEmpty);
      // Pas de note vide enregistree.
      final sansNote = app.logActivityForChildren(childIds: ['ana'], activityTypeId: 'e1', note: '   ');
      expect(sansNote.single.note, isNull);
    });

    test('annuler supprime exactement ce qui vient d\'etre cree', () async {
      final app = await newApp();
      final created = app.logActivityForChildren(
          childIds: ['lea', 'tom'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);
      for (final log in created) {
        app.deleteActivityLog(log.id);
      }
      expect(app.activitiesForChild('lea'), isEmpty);
      expect(app.activitiesForChild('tom'), isEmpty);
    });

    test('valider l\'etape 1 pour plusieurs deverrouille l\'etape 2', () async {
      final app = await newApp();
      app.logActivityForChildren(
          childIds: ['lea', 'tom'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);
      for (final id in ['lea', 'tom']) {
        final r = AtelierEligibilityService.evaluate(
            provider: app, child: app.childById(id)!, atelier: app.activityTypeById('e2')!);
        expect(r.isAllowed, isTrue, reason: id);
      }
      expect(
          AtelierEligibilityService.evaluate(provider: app, child: app.childById('ana')!, atelier: app.activityTypeById('e2')!)
              .isAllowed,
          isFalse);
    });

    testWidgets('ecran : cocher une section puis enregistrer (etape verrouillee grisee)', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(newApp))!;
      // Lea et Tom ont fini l'etape 1 : l'etape 2 leur est ouverte, pas a Ana.
      app.logActivityForChildren(
          childIds: ['lea', 'tom'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(home: BulkValidationScreen(atelier: app.activityTypeById('e2')!)),
      ));
      await tester.pump();

      expect(find.text('Choisissez des élèves'), findsOneWidget);
      // Ana est grisee : verrouillee par l'etape 1.
      expect(find.textContaining('Termine d\'abord'), findsOneWidget);

      await tester.tap(find.text('MS'));
      await tester.pump();
      expect(find.textContaining('pour 2 élève(s)'), findsOneWidget);

      await tester.tap(find.textContaining('pour 2 élève(s)'));
      await tester.pump();
      expect(app.activitiesForChild('lea').where((l) => l.activityTypeId == 'e2'), isNotEmpty);
      expect(app.activitiesForChild('tom').where((l) => l.activityTypeId == 'e2'), isNotEmpty);
      expect(app.activitiesForChild('ana'), isEmpty);

      // Laisse finir les ecritures en base (E/S reelles, horloge de test
      // simulee) puis les minuteurs de verrou sqflite : rien ne doit survivre.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Scan & Go > Plusieurs eleves : choisir l\'atelier puis les eleves', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(newApp))!;
      app.logActivityForChildren(
          childIds: ['lea', 'tom'], activityTypeId: 'e1', evaluationStatusId: app.evaluationStatuses.last.id);

      // Aucun atelier d'avance : l'ecran commence par le choix.
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: BulkValidationScreen()),
      ));
      await tester.pump();
      expect(find.text('Quel atelier ou quelle étape ?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Étape e2');
      await tester.pump();
      // Le texte saisi est aussi dans le champ : on vise la ligne de la liste.
      await tester.tap(find.widgetWithText(ListTile, 'Étape e2'));
      await tester.pump();

      // L'etape est choisie : on peut en changer, et cocher les eleves.
      expect(find.text('Changer'), findsOneWidget);
      await tester.tap(find.text('MS'));
      await tester.pump();
      await tester.tap(find.textContaining('pour 2 élève(s)'));
      await tester.pump();
      expect(app.activitiesForChild('lea').where((l) => l.activityTypeId == 'e2'), isNotEmpty);
      expect(app.activitiesForChild('tom').where((l) => l.activityTypeId == 'e2'), isNotEmpty);
      expect(app.activitiesForChild('ana'), isEmpty);

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('ecran de depart : choisir l\'etape puis les eleves', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(newApp))!;

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(home: ParcoursStartScreen(progression: app.progressionById('p')!)),
      ));
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Étape 3 ·').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Toute la classe'));
      await tester.pump();
      await tester.tap(find.textContaining('à l\'étape 3'));
      await tester.pump();

      for (final id in ['lea', 'tom', 'ana']) {
        expect(app.childById(id)!.parcoursStarts['p'], 'e3', reason: id);
      }

      // Laisse finir les ecritures en base (E/S reelles, horloge de test
      // simulee) puis les minuteurs de verrou sqflite : rien ne doit survivre.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
