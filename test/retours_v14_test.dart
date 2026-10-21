import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/atelier_eligibility_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Retours de la version 1.4 : ateliers supprimes, observations orphelines,
/// ateliers obligatoires pour une section.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<AppStateProvider> classe() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('retours_');
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'retours_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: dir.path,
      autoLoad: false,
    );
    await app.initialize();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', group: 'PS', colorHex: '#4E9F3D', avatarText: 'L'));
    app.addOrUpdateActivityType(
        ActivityType(id: 'peinture', name: 'Peinture', spaceId: 'space_1', colorHex: '#FF7043'));
    for (var i = 0; i < 3; i++) {
      app.logActivity(ActivityLog(
          id: 'obs_$i', childId: 'lea', activityTypeId: 'peinture', timestamp: DateTime.now()));
    }
    return app;
  }

  test('supprimer un atelier supprime aussi ses observations (plus d\'orphelines)', () async {
    final app = await classe();
    expect(app.activityCountForType('peinture'), 3);
    app.deleteActivityType('peinture');
    expect(app.activities.where((a) => a.activityTypeId == 'peinture'), isEmpty);
    expect(app.orphanActivities, isEmpty);
  });

  test('les observations orphelines existantes se nettoient, apres sauvegarde', () async {
    final app = await classe();
    // Orphelines comme en laissaient les anciennes versions (ou une synchro).
    app.logActivity(ActivityLog(
        id: 'sans_atelier', childId: 'lea', activityTypeId: 'disparu', timestamp: DateTime.now()));
    app.logActivity(ActivityLog(
        id: 'sans_eleve', childId: 'parti', activityTypeId: 'peinture', timestamp: DateTime.now()));
    expect(app.orphanActivities.map((a) => a.id).toSet(), {'sans_atelier', 'sans_eleve'});

    expect(await app.purgeOrphanActivities(), 2);
    expect(app.orphanActivities, isEmpty);
    expect(app.activities.where((a) => a.id.startsWith('obs_')), hasLength(3),
        reason: 'les observations valides restent');
    // La sauvegarde la plus recente contient encore les orphelines : restaurable.
    final derniere = (await app.listAutoBackups()).first;
    expect(await derniere.readAsString(), contains('sans_atelier'));
  });

  test('un atelier obligatoire pour une section reste accessible aux autres', () async {
    final app = await classe();
    final pourMs = ActivityType(
        id: 'graphisme',
        name: 'Graphisme',
        spaceId: 'space_1',
        colorHex: '#FFA726',
        isObligatory: true,
        obligatoryGroups: const ['MS']);
    final lea = app.children.firstWhere((c) => c.id == 'lea'); // en PS
    final result = AtelierEligibilityService.evaluate(provider: app, child: lea, atelier: pourMs);
    expect(result.isAllowed, isTrue);
    expect(pourMs.isObligatoryForGroup('PS'), isFalse, reason: 'facultatif pour la PS');
    expect(pourMs.isObligatoryForGroup('MS'), isTrue);
  });
}
