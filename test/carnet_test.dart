import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/data/eduscol_data.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/carnet_entry.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/carnet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Carnet de suivi et synthese de fin de maternelle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory docs;
  late String dbName;
  AppStateProvider open() =>
      AppStateProvider(database: AppDatabase(fileName: dbName), documentsPath: docs.path, autoLoad: false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('carnet_');
    dbName = 'carnet_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  test('periodes de l\'annee scolaire', () {
    final p1 = CarnetService.periodRange('2026-2027', 'P1');
    expect(p1.start, DateTime(2026, 9, 1));
    final p5 = CarnetService.periodRange('2026-2027', 'P5');
    expect(p5.end.year, 2027);
  });

  test('reussites par domaine, suggestion, saisies, PDF, effacement', () async {
    final app = open();
    await app.initialize();
    await app.whenStartupBackupDone();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L', group: 'GS'));
    final sub = EduscolData.subdomains.firstWhere((s) => s.domainId == 'd2_maths');
    final top = app.evaluationStatuses.last.id;
    final first = app.evaluationStatuses.first.id;
    app.addOrUpdateActivityType(ActivityType(
        id: 'tri', name: 'Tri', spaceId: 's', colorHex: '#4E9F3D', domaineId: 'd2_maths', sousDomaineId: sub.id));
    app.addOrUpdateActivityType(ActivityType(
        id: 'compter', name: 'Compter', spaceId: 's', colorHex: '#4E9F3D', domaineId: 'd2_maths', sousDomaineId: sub.id));
    final now = DateTime.now();
    app.logActivity(ActivityLog(id: 'o1', childId: 'lea', activityTypeId: 'tri', timestamp: now, evaluationStatusId: top));
    app.logActivity(
        ActivityLog(id: 'o2', childId: 'lea', activityTypeId: 'compter', timestamp: now, evaluationStatusId: first));

    final range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final lea = app.childById('lea')!;
    final data = CarnetService.byDomain(app, lea, range);
    expect(data['d2_maths']!.done.map((i) => i.atelier.id), ['tri']);
    expect(data['d2_maths']!.ongoing.map((i) => i.atelier.id), ['compter']);
    // Un atelier sur deux reussi : « reussit souvent » (au moins la moitie).
    expect(CarnetService.suggestedLevel(app, lea, sub.id), CarnetEntry.levelOften);

    app.saveCarnet(app.carnetFor('lea', 'P1').copyWith(comments: {'d2_maths': 'Très à l\'aise'}));
    app.saveCarnet(app.carnetFor('lea', CarnetEntry.synthese)
        .copyWith(levels: {sub.id: CarnetEntry.levelOften}, strengths: 'Curieuse'));

    expect(
        await CarnetService.buildCarnetBytes(
            provider: app, children: [lea], period: 'P1', range: range, format: PdfPageFormat.a4),
        isNotEmpty);
    expect(await CarnetService.buildSyntheseBytes(provider: app, children: [lea], format: PdfPageFormat.a4),
        isNotEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final reread = open();
    await reread.initialize();
    await reread.whenStartupBackupDone();
    expect(reread.carnetFor('lea', 'P1').comments['d2_maths'], 'Très à l\'aise');
    expect(reread.carnetFor('lea', CarnetEntry.synthese).levels[sub.id], CarnetEntry.levelOften);

    // Droit a l'effacement : les saisies du carnet partent avec l'eleve.
    await reread.eraseChildData('lea');
    expect(reread.carnetFor('lea', 'P1').comments, isEmpty);
    expect(reread.buildSyncSnapshot()['carnets'], isEmpty);
  });
}
