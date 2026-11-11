import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/need_group.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/need_group_suggestions.dart';
import 'package:petitpas/services/sync_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Groupes de besoin : enregistrement, suggestions, synchro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory docs;
  late String dbName;

  AppStateProvider open() => AppStateProvider(
        database: AppDatabase(fileName: dbName),
        documentsPath: docs.path,
        autoLoad: false,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('groupes_');
    dbName = 'groupes_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  test('enregistres, relus, et suivent la suppression d\'un eleve', () async {
    final app = open();
    await app.initialize();
    await app.whenStartupBackupDone();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
    app.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', colorHex: '#4E9F3D', avatarText: 'T'));
    app.saveNeedGroup(NeedGroup(id: 'g', name: 'Découpage', childIds: const ['lea', 'tom']));
    expect(app.needGroups.single.childIds, ['lea', 'tom']);

    final deleted = app.deleteChild('tom');
    expect(app.needGroupById('g')!.childIds, ['lea']);
    app.restoreChild(deleted);
    expect(app.needGroupById('g')!.childIds, containsAll(['lea', 'tom']), reason: 'annuler rend le groupe');

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final reread = open();
    await reread.initialize();
    await reread.whenStartupBackupDone();
    expect(reread.needGroupById('g')?.name, 'Découpage');
    expect(reread.buildSyncSnapshot()['need_groups'], isNotEmpty);
  });

  test('suggestions : meme etape de parcours, meme niveau sur un atelier', () async {
    final app = open();
    await app.initialize();
    await app.whenStartupBackupDone();
    for (final id in ['a', 'b', 'c']) {
      app.addOrUpdateChild(Child(id: id, firstname: id.toUpperCase(), colorHex: '#4E9F3D', avatarText: id));
    }
    app.saveProgression(Progression(id: 'p', name: 'Découpage', colorHex: '#42A5F5'));
    for (final n in ['bande', 'droite']) {
      app.addOrUpdateActivityType(ActivityType(
          id: n, name: n, spaceId: '', progressionId: 'p', colorHex: '#42A5F5',
          position: app.nextPositionInProgression('p')));
    }
    final enCours = app.evaluationStatuses.first.id;
    app.addOrUpdateActivityType(ActivityType(id: 'perles', name: 'Perles', spaceId: 's', colorHex: '#000000'));
    for (final id in ['a', 'b']) {
      app.logActivity(ActivityLog(
          id: 'p_$id', childId: id, activityTypeId: 'perles', timestamp: DateTime.now(), evaluationStatusId: enCours));
    }

    final titles = NeedGroupSuggestions.suggest(app).map((s) => s.title).toList();
    expect(titles, contains('Découpage · étape 1 : bande'));
    expect(titles.where((t) => t.startsWith('Perles ·')), hasLength(1));
    final perles = NeedGroupSuggestions.suggest(app).firstWhere((s) => s.title.startsWith('Perles ·'));
    expect(perles.children.map((c) => c.id), ['a', 'b']);
  });

  test('synchro avec une version qui ne connait pas les groupes : rien n\'est efface', () {
    final group = NeedGroup(id: 'g', name: 'Découpage', childIds: const ['lea']).toMap();
    final local = {'children': [], 'need_groups': [group]};
    final old = {'children': []}; // ancienne version : pas de cle need_groups
    // Base commune : le groupe existait deja lors de la synchro precedente.
    final base = SyncMerge.fingerprints(SyncMerge.flatten(local));
    final merged = SyncMerge.merge(local: local, remote: old, base: base).snapshot;
    expect(merged['need_groups'], [group]);
    // Une suppression reelle (liste vide envoyee) reste prise en compte.
    final emptied = SyncMerge.merge(local: local, remote: {'children': [], 'need_groups': []}, base: base).snapshot;
    expect(emptied['need_groups'], isEmpty);
  });
}
