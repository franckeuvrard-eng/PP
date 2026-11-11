import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/models/referential.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/child_activity_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Rapport des eleves reglable : sons, referentiels, regroupement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('rapport genere avec chaque combinaison de reglages', () async {
    SharedPreferences.setMockInitialValues({});
    final docs = await Directory.systemTemp.createTemp('rapport_');
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'rapport_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: docs.path,
      autoLoad: false,
    );
    await app.initialize();
    await app.whenStartupBackupDone();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
    app.addOrUpdateReferential(const Referential(id: 'ceintures', name: 'Ceintures', groups: [
      ReferentialGroup(id: 'g', title: 'Couleurs', items: [ReferentialItem(id: 'blanche', label: 'Blanche')]),
    ]));
    app.addOrUpdateActivityType(ActivityType(
        id: 'tri', name: 'Tri', spaceId: app.spaces.first.id, colorHex: '#4E9F3D',
        domaineId: 'd2_maths', domaine: "L'acquisition des premiers outils mathématiques", sousDomaineId: 'c1_m1'));
    app.saveProgression(Progression(id: 'p', name: 'Découpage', colorHex: '#42A5F5'));
    app.addOrUpdateActivityType(ActivityType(
        id: 'bande', name: 'Bande', spaceId: '', progressionId: 'p', colorHex: '#42A5F5', position: 0));
    for (final (i, a) in ['tri', 'bande', 'tri'].indexed) {
      app.logActivity(ActivityLog(
          id: 'o$i', childId: 'lea', activityTypeId: a,
          timestamp: DateTime.now().subtract(Duration(days: i)), note: 'Observation $i'));
    }

    for (final options in const [
      ChildReportOptions(),
      ChildReportOptions(includeSons: false, referentialIds: {}),
      ChildReportOptions(groupActivities: false, onlyLatestPerAtelier: true),
      ChildReportOptions(referentialIds: {'ceintures'}),
    ]) {
      final bytes = await ChildActivityReportService.generateReportBytes(
          provider: app, children: app.children, format: PdfPageFormat.a4, options: options);
      expect(bytes, isNotEmpty);
    }
  });
}
