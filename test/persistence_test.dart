import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:petitpas/models/activity.dart';
import 'package:petitpas/models/child.dart';
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/app_database.dart';

/// Tests de la couche de persistance : migration de schema, echec de
/// chargement et cloture d'annee scolaire.
///
/// Ils tournent sur une vraie base SQLite via `sqflite_common_ffi`, deja
/// dependance de production pour l'apercu poste de travail. Aucun appareil
/// n'est necessaire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory racine;

  /// Nom de fichier de la base du test en cours.
  ///
  /// Unique par execution : `sqflite_common_ffi` conserve ses bases dans
  /// `.dart_tool/`, et un nom stable ferait hériter chaque test des donnees
  /// laissees par l'execution precedente.
  late String nomBase;

  Future<String> cheminBase(String nom) async =>
      '${await databaseFactory.getDatabasesPath()}/$nom';

  setUpAll(() {
    // flutter_test annonce Android comme plateforme : `AppDatabase._open()`
    // croirait tourner sur mobile et n'installerait pas la fabrique FFI.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // `_load()` lit SharedPreferences pour la reprise des anciennes versions.
    SharedPreferences.setMockInitialValues({});
    racine = await Directory.systemTemp.createTemp('petitpas_test_');
    nomBase = 'petitpas_test_${DateTime.now().microsecondsSinceEpoch}.db';
    await databaseFactory.deleteDatabase(await cheminBase(nomBase));
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(await cheminBase(nomBase));
    if (await racine.exists()) {
      try {
        await racine.delete(recursive: true);
      } catch (_) {
        // Windows garde parfois un verrou sur la base : sans consequence, le
        // repertoire temporaire sera nettoye par le systeme.
      }
    }
  });

  AppStateProvider creerProvider({String? nom, String? documentsPath}) =>
      AppStateProvider(
        database: AppDatabase(fileName: nom ?? nomBase),
        documentsPath: documentsPath ?? racine.path,
        autoLoad: false,
      );

  group('Migration de schema', () {
    test('une base v1 est reprise sans perdre ses donnees', () async {
      final nom = nomBase;
      final chemin = await cheminBase(nom);
      await databaseFactory.deleteDatabase(chemin);

      // Base au schema d'origine, tel qu'il a ete livre.
      final v1 = await databaseFactory.openDatabase(
        chemin,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final table in ['children', 'spaces', 'activity_types', 'activities']) {
              await db.execute(
                'CREATE TABLE $table (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
              );
            }
            await db.execute(
              'CREATE TABLE sons (child_id TEXT NOT NULL, son TEXT NOT NULL, '
              'statut INTEGER NOT NULL, PRIMARY KEY (child_id, son))',
            );
            await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
          },
        ),
      );
      await v1.insert('children', {
        'id': 'child_1',
        'data': '{"id":"child_1","firstname":"Zoé","lastname":"Martin"}',
      });
      await v1.close();

      // Reouverture par le code de production : onUpgrade doit s'appliquer.
      final db = AppDatabase(fileName: nom);
      final enfants = await db.readChildren();

      expect(enfants, hasLength(1),
          reason: 'la migration ne doit pas perdre les eleves existants');
      expect(enfants.single.firstname, 'Zoé');
      // La table ajoutee par la v2 doit exister, sinon la cloture d'annee
      // echouerait sur une installation mise a jour.
      expect(await db.readArchives(), isEmpty);
    });

    test('une base neuve possede aussi les tables des migrations', () async {
      final db = AppDatabase(fileName: nomBase);
      expect(await db.readArchives(), isEmpty);
      expect(await db.readChildren(), isEmpty);
    });
  });

  group('Echec de chargement', () {
    test('n\'affiche jamais la classe d\'exemple', () async {
      final nom = nomBase;
      final chemin = await cheminBase(nom);
      await databaseFactory.deleteDatabase(chemin);
      // Un fichier qui n'est pas une base SQLite : l'ouverture leve.
      await File(chemin).writeAsString('ceci n\'est pas une base de donnees');

      final provider = creerProvider(nom: nom);
      await provider.initialize();

      expect(provider.loadFailed, isTrue);
      expect(provider.children, isEmpty,
          reason: 'les 4 eleves d\'exemple ne doivent jamais passer pour de '
              'vraies donnees');
      expect(provider.activities, isEmpty);
      expect(provider.isLoaded, isTrue,
          reason: 'l\'application doit demarrer pour atteindre la restauration');
    });

    test('un chargement reussi laisse le drapeau a faux', () async {
      final provider = creerProvider();
      await provider.initialize();
      expect(provider.loadFailed, isFalse);
    });
  });

  group('Cloture d\'annee scolaire', () {
    /// Provider charge, avec un eleve et une observation ajoutes.
    ///
    /// Une base neuve est semee avec la classe d'exemple (`_seedInitialData`),
    /// volontairement : l'application ne doit pas s'ouvrir entierement vide au
    /// premier lancement. Les tests comptent donc en relatif.
    Future<AppStateProvider> providerAvecDonnees({String? documentsPath}) async {
      final provider = creerProvider(documentsPath: documentsPath);
      await provider.initialize();
      provider.addOrUpdateChild(Child(
        id: 'child_test',
        firstname: 'Zoé',
        lastname: 'Martin',
        birthdate: '2022-05-01',
        group: 'Groupe Rouge',
        colorHex: '#4E9F3D',
        avatarText: 'ZM',
      ));
      provider.logActivity(ActivityLog(
        id: 'log_test',
        childId: 'child_test',
        activityTypeId: provider.activityTypes.first.id,
        timestamp: DateTime(2026, 3, 12),
      ));
      return provider;
    }

    test('archive puis vide la classe en conservant la configuration', () async {
      final provider = await providerAvecDonnees();
      final ateliersAvant = provider.activityTypes.length;
      final espacesAvant = provider.spaces.length;
      final elevesAvant = provider.children.length;
      final observationsAvant = provider.activities.length;

      final archive =
          await provider.startNewSchoolYear(nouvelleAnnee: '2027-2028');

      expect(archive, isNotNull);
      expect(archive!.childCount, elevesAvant);
      expect(archive.activityCount, observationsAvant);
      expect(archive.sizeBytes, greaterThan(0));

      // Le fichier doit exister sur le disque, pas seulement en base.
      final fichier = await provider.archiveFile(archive);
      expect(fichier, isNotNull);
      expect(await fichier!.length(), archive.sizeBytes);

      expect(provider.children, isEmpty);
      expect(provider.activities, isEmpty);
      expect(provider.activityTypes, hasLength(ateliersAvant),
          reason: 'les ateliers se reutilisent d\'une annee sur l\'autre');
      expect(provider.spaces, hasLength(espacesAvant));
      expect(provider.classSettings.schoolYear, '2027-2028');
      expect(await provider.listArchives(), hasLength(1));
    });

    test('la classe reste vide apres relecture depuis la base', () async {
      final nom = nomBase;
      final provider = creerProvider(nom: nom);
      await provider.initialize();
      provider.addOrUpdateChild(Child(
        id: 'child_test',
        firstname: 'Zoé',
        birthdate: '2022-05-01',
        group: 'Groupe Rouge',
        colorHex: '#4E9F3D',
        avatarText: 'ZM',
      ));
      await provider.startNewSchoolYear(nouvelleAnnee: '2027-2028');

      // Un second provider sur la meme base : l'effacement doit avoir ete
      // ecrit, pas seulement applique en memoire.
      final relu = creerProvider(nom: nom);
      await relu.initialize();
      expect(relu.children, isEmpty);
      expect(relu.classSettings.schoolYear, '2027-2028');
      expect(await relu.listArchives(), hasLength(1));
    });

    test('n\'efface rien si l\'archive ne peut pas etre ecrite', () async {
      // Repertoire de documents pointant sur un fichier : la creation du
      // sous-dossier `archives/` echoue, comme sur un stockage sature.
      final obstacle = File('${racine.path}/pas_un_dossier');
      await obstacle.writeAsString('x');

      final provider = await providerAvecDonnees(documentsPath: obstacle.path);
      final elevesAvant = provider.children.length;
      final observationsAvant = provider.activities.length;
      expect(elevesAvant, greaterThan(0));

      final archive =
          await provider.startNewSchoolYear(nouvelleAnnee: '2027-2028');

      expect(archive, isNull);
      expect(provider.children, hasLength(elevesAvant),
          reason: 'une archive manquee ne doit jamais couter les donnees');
      expect(provider.activities, hasLength(observationsAvant));
      expect(provider.classSettings.schoolYear, isNot('2027-2028'));
      expect(await provider.listArchives(), isEmpty);
    });
  });
}
