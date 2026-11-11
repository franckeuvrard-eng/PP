import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/models/space.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/atelier_eligibility_service.dart';
import 'package:petitpas/services/icloud_sync.dart';
import 'package:petitpas/services/progression_migration.dart';
import 'package:petitpas/services/sync_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sync_fakes.dart';

/// Version 1.5 : les progressions ne sont plus un mode des espaces. Un
/// atelier est dans un espace OU dans une progression ; les anciens espaces
/// « mode progression » deviennent des progressions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Donnees au format d'une version 1.4 : un espace normal, un espace en
  /// mode progression avec deux ateliers ordonnes, une observation.
  Map<String, dynamic> legacy() => {
        ...snap([
          {'id': 'lea', 'firstname': 'Léa', 'colorHex': '#4E9F3D', 'avatarText': 'L'}
        ]),
        'spaces': [
          {'id': 'coin', 'name': 'Coin peinture', 'colorHex': '#FF7043', 'isProgression': false},
          {
            'id': 'decoupage',
            'name': 'Découpage',
            'colorHex': '#42A5F5',
            'iconName': 'content_cut',
            'description': 'Ciseaux',
            'isProgression': true,
            'progressionMinStatusId': 'acquis',
          },
        ],
        'activity_types': [
          {'id': 'peinture', 'name': 'Peinture', 'spaceId': 'coin', 'colorHex': '#FF7043'},
          {'id': 'bande', 'name': 'Couper une bande', 'spaceId': 'decoupage', 'colorHex': '#42A5F5', 'position': 0},
          {'id': 'courbe', 'name': 'Couper une courbe', 'spaceId': 'decoupage', 'colorHex': '#42A5F5', 'position': 1},
        ],
        'activities': [
          {'id': 'obs1', 'childId': 'lea', 'activityTypeId': 'bande', 'timestamp': '2026-09-10T10:00:00.000'},
        ],
      };

  group('conversion des anciens espaces « mode progression »', () {
    test('espace progression -> progression, ateliers -> jalons, rien d\'autre ne bouge', () {
      final out = migrateSpaceProgressions(legacy());
      expect([for (final s in out['spaces'] as List) s['id']], ['coin']);
      final progressions = out['progressions'] as List;
      expect(progressions, hasLength(1));
      expect(progressions.single, {
        'id': 'decoupage',
        'name': 'Découpage',
        'colorHex': '#42A5F5',
        'iconName': 'content_cut',
        'description': 'Ciseaux',
        'minStatusId': 'acquis',
      });
      final types = {for (final t in out['activity_types'] as List) t['id']: t};
      expect(types['peinture']!['spaceId'], 'coin');
      expect(types['peinture']!['progressionId'], isNull);
      expect(types['bande']!['progressionId'], 'decoupage');
      expect(types['bande']!['spaceId'], '');
      expect(types['courbe']!['position'], 1);
      expect(out['activities'], legacy()['activities']);
      expect(needsProgressionMigration(out), isFalse);
    });

    test('deterministe et idempotente : deux appareils obtiennent les memes donnees', () {
      final a = migrateSpaceProgressions(legacy());
      final b = migrateSpaceProgressions(legacy());
      expect(SyncMerge.hash(a), SyncMerge.hash(b));
      expect(SyncMerge.hash(migrateSpaceProgressions(a)), SyncMerge.hash(a));
      final plain = snap([]);
      expect(identical(migrateSpaceProgressions(plain), plain), isTrue);
    });

    test('fusion d\'un appareil converti avec un appareil 1.4 : aucun conflit', () {
      final result = SyncMerge.merge(local: migrateSpaceProgressions(legacy()), remote: legacy());
      expect(result.conflicts, isEmpty);
      expect(result.stats.changes, isEmpty);
      expect(result.snapshot['progressions'], hasLength(1));
    });
  });

  group('dans l\'application', () {
    late Directory dir;
    late String dbName;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('progressions_');
      dbName = 'progressions_${DateTime.now().microsecondsSinceEpoch}.db';
    });

    AppStateProvider app() => AppStateProvider(
          database: AppDatabase(fileName: dbName),
          documentsPath: dir.path,
          autoLoad: false,
        );

    test('une base 1.4 est convertie au chargement, apres une sauvegarde', () async {
      final ancienne = app();
      await ancienne.initialize();
      ancienne.addOrUpdateSpace(Space(
          id: 'decoupage', name: 'Découpage', colorHex: '#42A5F5', isProgression: true));
      ancienne.addOrUpdateActivityType(ActivityType(
          id: 'bande', name: 'Bande', spaceId: 'decoupage', colorHex: '#42A5F5', position: 0));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final relue = app();
      await relue.initialize();
      expect(relue.spaces.where((s) => s.id == 'decoupage'), isEmpty);
      expect(relue.progressionById('decoupage')?.name, 'Découpage');
      final bande = relue.activityTypeById('bande')!;
      expect(bande.progressionId, 'decoupage');
      expect(relue.ateliersInSpace(''), isEmpty);
      expect(relue.containerOf(bande)?.isProgression, isTrue);
      expect(relue.placeOf(bande)?.name, 'Découpage');
      expect(Directory('${dir.path}/backups').listSync(), isNotEmpty,
          reason: 'sauvegarde automatique avant conversion');

      // Et la conversion tient apres relecture.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final encore = app();
      await encore.initialize();
      expect(encore.progressions.map((p) => p.id), contains('decoupage'));
      expect(encore.activityTypeById('bande')!.progressionId, 'decoupage');
    });

    test('des donnees 1.4 recues par synchro sont converties', () async {
      final a = app();
      await a.initialize();
      await a.applySyncSnapshot(legacy());
      expect(a.progressions.single.id, 'decoupage');
      expect(a.ateliersInProgressionOrdered('decoupage').map((t) => t.id), ['bande', 'courbe']);
      expect(a.ateliersInSpace('coin').map((t) => t.id), ['peinture']);
      expect(a.activities.single.activityTypeId, 'bande');
    });

    test('jalons : ordre, verrou tant que le precedent n\'a pas le seuil, suppression en cascade', () async {
      final a = app();
      await a.initialize();
      final statuses = a.evaluationStatuses;
      expect(statuses, isNotEmpty);
      a.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
      a.saveProgression(Progression(id: 'p', name: 'Découpage', colorHex: '#42A5F5', minStatusId: statuses.last.id));
      for (final id in ['un', 'deux']) {
        a.addOrUpdateActivityType(ActivityType(
            id: id, name: id, spaceId: '', progressionId: 'p', colorHex: '#42A5F5',
            position: a.nextPositionInProgression('p')));
      }
      expect(a.ateliersInProgressionOrdered('p').map((t) => t.id), ['un', 'deux']);

      final lea = a.children.firstWhere((c) => c.id == 'lea');
      AtelierEligibility status(String id) => AtelierEligibilityService.evaluate(
          provider: a, child: lea, atelier: a.activityTypeById(id)!).status;
      expect(status('un'), isNot(AtelierEligibility.blockedProgression));
      expect(status('deux'), AtelierEligibility.blockedProgression);

      a.logActivity(ActivityLog(
          id: 'o1', childId: 'lea', activityTypeId: 'un',
          evaluationStatusId: statuses.last.id, timestamp: DateTime.now()));
      expect(status('deux'), isNot(AtelierEligibility.blockedProgression));

      a.reorderAteliersInProgression('p', ['deux', 'un']);
      expect(a.ateliersInProgressionOrdered('p').map((t) => t.id), ['deux', 'un']);

      expect(a.activityCountForProgression('p'), 1);
      a.deleteProgression('p');
      expect(a.progressions, isEmpty);
      expect(a.activityTypeById('un'), isNull);
      expect(a.activities.where((l) => l.id == 'o1'), isEmpty);
    });
  });

  group('iCloud', () {
    Uint8List file(Map<String, dynamic> data) => Uint8List.fromList(utf8.encode(json.encode({
          'format': 1,
          'lineage': 'lignee',
          'by': 'iPad 1.4',
          'data': data,
        })));

    test('l\'ancien fichier est lu et converti, jamais reecrit ; le nouveau est cree', () async {
      final cloud = FakeCloud();
      final old = file(legacy());
      cloud.files[CloudSync.legacyClassFile] = old;
      final mac = FakeHost('mac', snap([]));

      final outcome = await CloudSync(mac, cloud).sync();
      expect(outcome.status, isNot(CloudSyncStatus.error), reason: outcome.message);
      expect(cloud.files[CloudSync.legacyClassFile], old);
      expect(cloud.files.containsKey(CloudSync.classFile), isTrue);
      final written = json.decode(utf8.decode(cloud.files[CloudSync.classFile]!)) as Map;
      expect((written['data'] as Map)['progressions'], hasLength(1));
      expect(mac.data['progressions'], hasLength(1));
      expect([for (final s in mac.data['spaces'] as List) s['id']], ['coin']);
    });
  });
}
