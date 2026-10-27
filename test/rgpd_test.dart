import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/atelier_pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Droit a l'effacement d'un eleve, et fiche d'un parcours.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppStateProvider app;
  late Directory docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('rgpd_');
    app = AppStateProvider(
      database: AppDatabase(fileName: 'rgpd_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: docs.path,
      autoLoad: false,
    );
    await app.initialize();
    await app.whenStartupBackupDone();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L'));
    app.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', colorHex: '#4E9F3D', avatarText: 'T'));
    app.addOrUpdateActivityType(ActivityType(id: 'peinture', name: 'Peinture', spaceId: 's', colorHex: '#FF7043'));
    for (final rel in ['activities/lea.jpg', 'activities/groupe.jpg']) {
      await File('${docs.path}/$rel').create(recursive: true);
    }
    app.logActivity(ActivityLog(
        id: 'o1', childId: 'lea', activityTypeId: 'peinture', timestamp: DateTime.now(),
        photoPaths: ['activities/lea.jpg']));
    // Observation de groupe : la meme photo pour Lea et Tom.
    for (final id in ['lea', 'tom']) {
      app.logActivity(ActivityLog(
          id: 'g_$id', childId: id, activityTypeId: 'peinture', timestamp: DateTime.now(),
          photoPaths: ['activities/groupe.jpg']));
    }
  });

  test('effacer un eleve : fiche, observations et ses seules photos', () async {
    expect(app.activityCountForChild('lea'), 2);
    expect(await app.eraseChildData('lea'), 2);

    expect(app.childById('lea'), isNull);
    expect(app.activities.where((l) => l.childId == 'lea'), isEmpty);
    expect(app.activities.map((l) => l.id), contains('g_tom'), reason: 'les observations de Tom restent');
    // Sa photo part a la corbeille ; celle du groupe sert encore a Tom.
    expect(File('${docs.path}/activities/lea.jpg').existsSync(), isFalse);
    expect(File('${docs.path}/corbeille_medias/activities/lea.jpg').existsSync(), isTrue);
    expect(File('${docs.path}/activities/groupe.jpg').existsSync(), isTrue);
    // Une sauvegarde a ete faite juste avant.
    expect(await app.listAutoBackups(), isNotEmpty);
  });

  test('fiche d\'un parcours avec ses etapes', () async {
    app.saveProgression(Progression(id: 'p', name: 'Découpage', colorHex: '#42A5F5'));
    for (final id in ['bande', 'droite']) {
      app.addOrUpdateActivityType(ActivityType(
          id: id, name: id, spaceId: '', progressionId: 'p', colorHex: '#42A5F5',
          description: 'Couper', objectifs: const ['Tenir des ciseaux'],
          position: app.nextPositionInProgression('p')));
    }
    final bytes = await AtelierPdfService.buildParcoursBytes(
        provider: app, parcours: app.progressionById('p')!, format: PdfPageFormat.a4);
    expect(bytes, isNotEmpty);
  });
}
