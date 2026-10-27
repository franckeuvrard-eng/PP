import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/eduscol_data.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/coverage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A surveiller : domaines delaisses et objectifs non couverts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppStateProvider app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final docs = await Directory.systemTemp.createTemp('couverture_');
    app = AppStateProvider(
      database: AppDatabase(fileName: 'couverture_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: docs.path,
      autoLoad: false,
    );
    await app.initialize();
    await app.whenStartupBackupDone();
    // Classe minimale : les ateliers et eleves d'exemple fausseraient les comptes.
    for (final a in app.activityTypes.toList()) {
      app.deleteActivityType(a.id);
    }
    for (final c in app.children.toList()) {
      app.deleteChild(c.id);
    }
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
    app.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', colorHex: '#4E9F3D', avatarText: 'T'));
  });

  test('domaines sans observation recente, par eleve', () {
    final obj = EduscolData.objectives.firstWhere((o) => o.domainId == 'd2_maths');
    app.addOrUpdateActivityType(ActivityType(
        id: 'tri', name: 'Tri', spaceId: 's', colorHex: '#000000', domaineId: 'd2_maths', objectifs: [obj.text]));
    // Ancien domaine : compte pour les deux domaines qui l'ont remplace.
    app.addOrUpdateActivityType(
        ActivityType(id: 'sable', name: 'Sable', spaceId: 's', colorHex: '#000000', domaineId: 'd5_monde'));
    app.logActivity(ActivityLog(
        id: 'o1', childId: 'lea', activityTypeId: 'tri', timestamp: DateTime.now().subtract(const Duration(days: 2))));
    app.logActivity(ActivityLog(
        id: 'o2', childId: 'lea', activityTypeId: 'sable', timestamp: DateTime.now().subtract(const Duration(days: 30))));

    final gaps = CoverageService.domainGaps(app, days: 21);
    String keyOf(DomainGap g) => '${g.child.id}/${g.domain.id}';
    final keys = gaps.map(keyOf).toSet();
    // Lea : maths vue il y a 2 jours (pas d'alerte), le reste il y a 30 jours.
    expect(keys, isNot(contains('lea/d2_maths')));
    expect(keys, containsAll(['lea/d5_temps_espace', 'lea/d6_vivant_matiere']));
    // Tom : jamais observe ; les domaines sans aucun atelier ne comptent pas.
    expect(keys, containsAll(['tom/d2_maths', 'tom/d5_temps_espace']));
    expect(keys, isNot(contains('tom/d1_langage')));
    // Les « jamais » d'abord.
    expect(gaps.first.last, isNull);

    expect(CoverageService.domainGaps(app, days: 40).map(keyOf), isNot(contains('lea/d5_temps_espace')));
  });

  test('dupliquer un atelier, un espace, un parcours', () {
    final space = app.spaces.first;
    app.addOrUpdateActivityType(ActivityType(
        id: 'peinture', name: 'Peinture', spaceId: space.id, colorHex: '#000000',
        objectifs: const ['Dessiner'], photoPaths: const ['ateliers/p.jpg']));
    app.logActivity(ActivityLog(id: 'o', childId: 'lea', activityTypeId: 'peinture', timestamp: DateTime.now()));

    final a = app.duplicateActivityType('peinture')!;
    expect(a.id, isNot('peinture'));
    expect(a.name, 'Peinture (copie)');
    expect(a.spaceId, space.id);
    expect(a.objectifs, ['Dessiner']);
    expect(a.photoPaths, ['ateliers/p.jpg']);
    expect(app.activities.where((l) => l.activityTypeId == a.id), isEmpty, reason: 'pas d\'observation copiee');

    final s = app.duplicateSpace(space.id)!;
    expect(s.name, '${space.name} (copie)');
    expect(app.ateliersInSpace(s.id).map((x) => x.name), containsAll(['Peinture', 'Peinture (copie)']));
    expect(app.ateliersInSpace(space.id).length, app.ateliersInSpace(s.id).length);

    app.saveProgression(Progression(id: 'p', name: 'Découpage', colorHex: '#000000', targetGroups: const ['MS']));
    for (final n in ['bande', 'droite', 'courbe']) {
      app.addOrUpdateActivityType(ActivityType(
          id: n, name: n, spaceId: '', progressionId: 'p', colorHex: '#000000',
          position: app.nextPositionInProgression('p')));
    }
    final p = app.duplicateProgression('p')!;
    expect(p.name, 'Découpage (copie)');
    expect(p.targetGroups, ['MS']);
    expect(app.ateliersInProgressionOrdered(p.id).map((x) => x.name), ['bande', 'droite', 'courbe']);
    expect(app.ateliersInProgressionOrdered('p').length, 3, reason: 'l\'original est intact');

    // Etape dupliquee seule : en fin de son parcours.
    final e = app.duplicateActivityType('bande')!;
    expect(e.progressionId, 'p');
    expect(app.ateliersInProgressionOrdered('p').last.id, e.id);
  });

  test('objectifs du programme sans atelier', () {
    final (done0, total) = CoverageService.objectiveCoverage(app);
    expect(done0, 0);
    expect(total, EduscolData.objectives.length);

    final obj = EduscolData.objectives.firstWhere((o) => o.level == 'GS');
    app.addOrUpdateActivityType(
        ActivityType(id: 'a', name: 'A', spaceId: 's', colorHex: '#000000', objectifs: [obj.text]));
    expect(CoverageService.uncoveredObjectives(app), isNot(contains(obj)));
    final (doneGs, totalGs) = CoverageService.objectiveCoverage(app, levels: {'GS'});
    expect(doneGs, greaterThanOrEqualTo(1));
    expect(totalGs, EduscolData.objectives.where((o) => o.level == 'GS').length);
  });
}
