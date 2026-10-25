import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/data/eduscol_data.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/progression.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/atelier_eligibility_service.dart';
import 'package:petitpas/services/mandatory_ateliers_pdf_service.dart';
import 'package:petitpas/services/parcours_frise_pdf_service.dart';
import 'package:petitpas/services/parcours_progress.dart';
import 'package:petitpas/services/parcours_report_service.dart';
import 'package:petitpas/services/qr_sheets_pdf_service.dart';
import 'package:petitpas/services/atelier_grouping.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Parcours : sections ciblees, etape en cours, frise et suivi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sections du parcours : sauvegardees, vide = toute la classe', () {
    final tous = Progression(id: 'p', name: 'Découpage', colorHex: '#42A5F5');
    expect(tous.concernsGroup('PS'), isTrue);
    expect(tous.concernsGroup(null), isTrue);
    // Donnees d'une version anterieure, sans le champ.
    expect(Progression.fromMap(tous.toMap()..remove('targetGroups')).targetGroups, isEmpty);

    final ms = Progression.fromMap(tous.copyWith(targetGroups: ['MS']).toMap());
    expect(ms.targetGroups, ['MS']);
    expect(ms.concernsGroup('MS'), isTrue);
    expect(ms.concernsGroup('PS'), isFalse);
    expect(ms.concernsGroup(null), isFalse);
  });

  group('avec une classe', () {
    late AppStateProvider app;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('parcours_');
      app = AppStateProvider(
        database: AppDatabase(fileName: 'parcours_${DateTime.now().microsecondsSinceEpoch}.db'),
        documentsPath: dir.path,
        autoLoad: false,
      );
      await app.initialize();
      app.setSections(['PS', 'MS']);
      app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', group: 'MS', colorHex: '#4E9F3D', avatarText: 'L'));
      app.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', group: 'PS', colorHex: '#4E9F3D', avatarText: 'T'));
      app.saveProgression(Progression(
          id: 'p', name: 'Découpage', colorHex: '#42A5F5',
          minStatusId: app.evaluationStatuses.last.id, targetGroups: ['MS']));
      for (final id in ['bande', 'droite', 'courbe']) {
        app.addOrUpdateActivityType(ActivityType(
            id: id, name: id, spaceId: '', progressionId: 'p', colorHex: '#42A5F5',
            position: app.nextPositionInProgression('p')));
      }
      app.logActivity(ActivityLog(
          id: 'o1', childId: 'lea', activityTypeId: 'bande',
          evaluationStatusId: app.evaluationStatuses.last.id, timestamp: DateTime.now()));
    });

    test('etape en cours et eleves qui suivent le parcours', () {
      final p = app.progressionById('p')!;
      final steps = app.ateliersInProgressionOrdered('p');
      final pos = ParcoursProgress.of(provider: app, parcours: p, steps: steps, childId: 'lea');
      expect(pos.step, 1);
      expect(pos.current!.id, 'droite');
      expect(pos.finished, isFalse);
      expect(ParcoursProgress.childrenFollowing(app, p).map((c) => c.id), ['lea']);
    });

    test('hors section : etape proposee avec avertissement', () {
      final tom = app.childById('tom')!;
      final r = AtelierEligibilityService.evaluate(
          provider: app, child: tom, atelier: app.activityTypeById('bande')!);
      expect(r.status, AtelierEligibility.allowedWithWarning);
      expect(r.message, contains('Découpage'));
    });

    test('renommer une section suit sur le parcours', () {
      app.renameSection('MS', 'Moyens');
      expect(app.progressionById('p')!.targetGroups, ['Moyens']);
    });

    test('frise, suivi et plan de travail se generent', () async {
      final p = app.progressionById('p')!;
      for (final withNames in [false, true]) {
        final bytes = await ParcoursFrisePdfService.buildBytes(
            provider: app, parcours: p, format: PdfPageFormat.a4, withNames: withNames);
        expect(bytes, isNotEmpty);
      }
      expect(await ParcoursReportService.buildPdfBytes(provider: app, format: PdfPageFormat.a4), isNotEmpty);
      expect(
          await MandatoryAteliersPdfService.buildBytes(
              provider: app, children: app.children, format: PdfPageFormat.a4),
          isNotEmpty);
    });

    test('planches QR : badges, ateliers par domaine, etapes par parcours', () async {
      expect(await QrSheetsPdfService.badgesBytes(app, PdfPageFormat.a4), isNotEmpty);
      expect(await QrSheetsPdfService.ateliersBytes(app, PdfPageFormat.a4), isNotEmpty);
      expect(await QrSheetsPdfService.parcoursBytes(app, app.progressions, PdfPageFormat.a4), isNotEmpty);
    });

    test('ateliers ranges par domaine puis sous-domaine', () {
      final sub = EduscolData.subdomains.firstWhere((s) => s.title == 'Découvrir le monde de la matière et des objets');
      final obj = EduscolData.objectives.firstWhere((o) => o.subdomainId == sub.id);
      app.addOrUpdateActivityType(ActivityType(
          id: 'aimants', name: 'Aimants', spaceId: 's', colorHex: '#00BCD4',
          domaineId: obj.domainId, objectifs: [obj.text]));
      app.addOrUpdateActivityType(ActivityType(id: 'libre', name: 'Jeu libre', spaceId: 's', colorHex: '#00BCD4'));
      final groups = AtelierGrouping.byDomain(app.activityTypes.where((a) => !a.inProgression));
      final vivant = groups.firstWhere((g) => g.key == EduscolData.domainById(obj.domainId)!.title);
      expect(AtelierGrouping.bySubdomain(vivant.value).map((e) => e.key), contains(sub.title));
      // Sans domaine : en dernier.
      expect(groups.last.key, AtelierGrouping.noDomain);
      expect(groups.last.value.map((a) => a.id), contains('libre'));
      // Les etapes de parcours ne sont pas des ateliers d'espace.
      expect(groups.expand((g) => g.value).any((a) => a.inProgression), isFalse);
    });
  });
}
