import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:petitpas/data/eduscol_data.dart';
import 'package:petitpas/models/activity_type.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';
import 'package:petitpas/services/mandatory_ateliers_pdf_service.dart';

/// Plan de travail : vignettes portrait en grille (3 colonnes), sans titre d'espace.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le plan de travail tient 12 vignettes par page A4 portrait', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    final racine = await Directory.systemTemp.createTemp('petitpas_pdf_');
    addTearDown(() => racine.delete(recursive: true));

    final provider = AppStateProvider(
      database: AppDatabase(fileName: 'pdf_${DateTime.now().microsecondsSinceEpoch}.db'),
      documentsPath: racine.path,
      autoLoad: false,
    );
    await provider.initialize();

    // Les ateliers d'exemple semes a la creation ne comptent pas : seuls les
    // ateliers obligatoires pour la section du test sont imprimes.
    final child = Child(
      id: 'c',
      firstname: 'Léa',
      lastname: 'Durand',
      birthdate: '2022-01-01',
      group: 'PS',
      colorHex: '#4E9F3D',
      avatarText: 'LD',
    );
    provider.addOrUpdateChild(child);

    var n = 0;
    for (final domaine in EduscolData.domains) {
      final objectifs =
          EduscolData.objectives.where((o) => o.domainId == domaine.id).toList();
      for (var k = 0; k < 3; k++) {
        n++;
        provider.saveActivityType(ActivityType(
          id: 'atelier_$n',
          name: 'Atelier $n',
          spaceId: provider.spaces.first.id,
          colorHex: domaine.colorHex,
          domaine: domaine.title,
          domaineId: domaine.id,
          isObligatory: true,
          objectifs: objectifs.skip(k).take(k + 2).map((o) => o.text).toList(),
        ));
      }
    }
    expect(n, 15);

    final bytes = await MandatoryAteliersPdfService.buildBytes(
      provider: provider,
      children: [child],
      format: PdfPageFormat.a4,
    );
    final text = latin1.decode(bytes, allowInvalid: true);
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;

    // Tous les ateliers du plan (ceux de l'exemple + les 15 ajoutes) : 3
    // colonnes x 4 rangees par page.
    final total = provider.activityTypes
        .where((a) => !a.inProgression && a.isObligatoryForGroup('PS'))
        .length;
    expect(total, greaterThanOrEqualTo(15));
    expect(pages, (total / 12).ceil());
  });
}
