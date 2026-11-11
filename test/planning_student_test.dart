import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:petitpas/data/release_notes.dart';
import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/models/need_group.dart';
import 'package:petitpas/models/planning_slot.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/screens/student_mode_screen.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/mandatory_ateliers_pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/app_harness.dart';

/// Planning de la semaine et mode eleve.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStateProvider> classe() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    final docs = await Directory.systemTemp.createTemp('planning_');
    final app = AppStateProvider(
      database: AppDatabase(fileName: 'planning_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: docs.path,
      autoLoad: false,
    );
    await app.initialize();
    await app.whenStartupBackupDone();
    app.addOrUpdateChild(Child(id: 'lea', firstname: 'Léa', colorHex: '#4E9F3D', avatarText: 'L', group: 'MS'));
    app.addOrUpdateChild(Child(id: 'tom', firstname: 'Tom', colorHex: '#4E9F3D', avatarText: 'T', group: 'GS'));
    app.addOrUpdateActivityType(
        ActivityType(id: 'perles', name: 'Perles', spaceId: 's', colorHex: '#000000', isObligatory: true));
    app.addOrUpdateActivityType(
        ActivityType(id: 'pate', name: 'Pâte à sel', spaceId: 's', colorHex: '#000000', isObligatory: true));
    return app;
  }

  test('creneaux : toute la classe, section, groupe ; ateliers prevus', () async {
    final app = await classe();
    final today = DateTime.now();
    final week = PlanningSlot.weekOf(today);
    app.saveNeedGroup(NeedGroup(id: 'g', name: 'Fins', childIds: const ['tom']));
    app.savePlanningSlot(PlanningSlot(id: 's1', week: week, day: today.weekday.clamp(1, 5), target: 'section:MS', atelierIds: const ['perles']));
    app.savePlanningSlot(PlanningSlot(id: 's2', week: week, day: today.weekday.clamp(1, 5), target: 'group:g', atelierIds: const ['pate']));
    final lea = app.childById('lea')!, tom = app.childById('tom')!;
    final day = today.weekday <= 5 ? today : today.subtract(Duration(days: today.weekday - 5));
    expect(app.plannedAteliersFor(lea, day), {'perles'});
    expect(app.plannedAteliersFor(tom, day), {'pate'});
    expect(app.plannedAteliersForWeek(lea, today), {'perles'});
    expect(app.planningTargetLabel('group:g'), 'Fins');
    expect(app.buildSyncSnapshot()['planning'], hasLength(2));

    // Plan de travail : seulement ce qui est prevu cette semaine.
    expect(
        await MandatoryAteliersPdfService.buildBytes(
            provider: app, children: [lea], format: PdfPageFormat.a4,
            options: const WorkPlanOptions(onlyPlannedThisWeek: true)),
        isNotEmpty);
  });

  test('mode eleve : saisie a valider, puis validee par l\'adulte', () async {
    final app = await classe();
    app.logActivity(ActivityLog(
        id: 'e1', childId: 'lea', activityTypeId: 'perles', timestamp: DateTime.now(), pendingValidation: true));
    expect(app.pendingLogs.map((l) => l.id), ['e1']);
    expect(app.statusLabel(app.pendingLogs.first), 'À valider');
    // Le marqueur n'est ecrit que s'il est vrai : les autres observations ne changent pas.
    expect(ActivityLog(id: 'x', childId: 'a', activityTypeId: 'b', timestamp: DateTime(2026)).toMap(),
        isNot(contains('pendingValidation')));
    expect(ActivityLog.fromMap(app.pendingLogs.first.toMap()).pendingValidation, isTrue);

    app.validateLog('e1', app.evaluationStatuses.last.id);
    expect(app.pendingLogs, isEmpty);
    expect(app.activities.firstWhere((l) => l.id == 'e1').evaluationStatusId, app.evaluationStatuses.last.id);
  });

  testWidgets('ecran eleve : choisir sa photo puis l\'atelier', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (app, sync) = await pumpPetitPas(tester, prepare: (app) {
      app.markOnboardingDone();
      app.markReleaseNotesSeen(kReleaseNotes.first.version);
      app.addOrUpdateActivityType(ActivityType(id: 'perles', name: 'Perles', spaceId: app.spaces.first.id, colorHex: '#000000'));
    });
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const StudentModeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Qui es-tu ?'), findsOneWidget);
    final child = app.children.first;
    await tester.tap(find.text(child.firstname).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perles'));
    await tester.pump();
    expect(find.text('Bravo ${child.firstname} !'), findsOneWidget);
    expect(app.pendingLogs.where((l) => l.childId == child.id && l.activityTypeId == 'perles'), hasLength(1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Sortie : sans Face ID (en test), la confirmation de secours ferme le mode.
    await tester.tap(find.text('Adulte'));
    // La reponse (absente en test) du module d'authentification arrive en
    // asynchrone reel.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    expect(find.text('Qui es-tu ?'), findsNothing, reason: 'le mode eleve doit se fermer');
    await endPetitPas(tester, sync);
  });
}
