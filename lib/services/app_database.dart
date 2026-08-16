import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/sons_data.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/class_settings.dart';
import '../models/evaluation_status.dart';
import '../models/referential.dart';
import '../models/school_year_archive.dart';
import '../models/space.dart';
import '../utils/platform_support.dart';

/// Stockage persistant de l'application.
///
/// Remplace l'enregistrement dans SharedPreferences, qui reecrivait la
/// totalite des donnees a chaque modification : au-dela de quelques centaines
/// d'observations le cout devenait sensible, et une ecriture interrompue
/// pouvait emporter l'ensemble. Ici chaque enregistrement est ecrit seul, dans
/// une transaction.
///
/// Les entites conservent leur serialisation `toMap()` existante : les colonnes
/// se limitent a la cle primaire et a une charge JSON. C'est volontaire — cela
/// evite une migration de schema a chaque champ ajoute a un modele, et les
/// volumes en jeu (quelques milliers de lignes) ne justifient pas d'indexer
/// davantage.
class AppDatabase {
  static const _defaultDbName = 'petitpas.db';

  /// Version du schema. **Toute evolution passe par [_migrate]**, jamais par une
  /// retouche de [_createV1] : les installations deja deployees ne rejouent que
  /// les migrations manquantes.
  static const _schemaVersion = 5;

  /// Tables « entite » : cle primaire texte + JSON.
  ///
  /// `archives` en est volontairement absente : [replaceAll] vide cette liste
  /// avant de restaurer une sauvegarde, et l'historique des annees archivees ne
  /// doit pas disparaitre a cette occasion. Les helpers [_readAll] et [_upsert]
  /// etant generiques, ils fonctionnent dessus sans y etre inscrits.
  static const _entityTables = [
    'children',
    'spaces',
    'activity_types',
    'activities',
  ];

  /// Nom du fichier de base. Parametrable pour que chaque test dispose de sa
  /// propre base sans que la production ait a s'en soucier.
  AppDatabase({String? fileName}) : _fileName = fileName ?? _defaultDbName;

  final String _fileName;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    if (!isMobilePlatform) {
      // Poste de travail : sqflite n'a pas d'implementation native, on passe
      // par SQLite embarque via FFI.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _schemaVersion,
      // Une base neuve part du schema v1 puis rejoue les memes migrations
      // qu'une base existante. Sans cela, la creation et la mise a jour
      // finiraient par diverger : c'est le defaut classique qui ne se voit
      // qu'une fois les premieres installations deja livrees.
      onCreate: (db, version) async {
        await _createV1(db);
        for (var v = 2; v <= version; v++) {
          await _migrate(db, v);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          await _migrate(db, v);
        }
      },
    );
  }

  /// Schema d'origine, fige. Ne plus le modifier : ajouter une migration.
  Future<void> _createV1(Database db) async {
    for (final table in _entityTables) {
      await db.execute(
        'CREATE TABLE $table (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
      );
    }
    await db.execute(
      'CREATE TABLE sons (child_id TEXT NOT NULL, son TEXT NOT NULL, '
      'statut INTEGER NOT NULL, PRIMARY KEY (child_id, son))',
    );
    // Reglages unitaires : theme, verrou biometrique, parametres de classe,
    // niveaux d'evaluation, marqueurs de migration.
    await db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  /// Applique la migration menant a [version].
  ///
  /// Chaque palier doit rester rejouable sur une base v1 d'origine comme sur
  /// une base neuve, et ne jamais supprimer de donnees.
  Future<void> _migrate(Database db, int version) async {
    switch (version) {
      case 2:
        // Fiches des annees scolaires archivees (cf. SchoolYearArchive).
        await db.execute(
          'CREATE TABLE IF NOT EXISTS archives '
          '(id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
      case 3:
        // Historique des changements de statut des sons, pour le graphique
        // de progression. Distincte de `sons` (etat courant uniquement) :
        // append-only, jamais purgee par un simple changement de statut.
        await db.execute(
          'CREATE TABLE IF NOT EXISTS sons_history '
          '(id INTEGER PRIMARY KEY AUTOINCREMENT, child_id TEXT NOT NULL, '
          'son TEXT NOT NULL, statut INTEGER NOT NULL, changed_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sons_history_child '
          'ON sons_history (child_id)',
        );
      case 4:
        // Referentiels personnalises (ceintures de couleur, Montessori, ou
        // tout autre systeme saisi par l'enseignant) et le statut de chaque
        // item pour chaque eleve. Hors de _entityTables comme `archives` :
        // ce n'est pas une entite generique, elle a ses propres methodes.
        await db.execute(
          'CREATE TABLE IF NOT EXISTS referentials '
          '(id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS referential_status '
          '(child_id TEXT NOT NULL, referential_id TEXT NOT NULL, '
          'item_id TEXT NOT NULL, statut INTEGER NOT NULL, '
          'PRIMARY KEY (child_id, referential_id, item_id))',
        );
      case 5:
        // Historique des referentiels personnalises, meme principe que
        // sons_history : append-only, pour le graphique de progression et le
        // radar de chaque referentiel.
        await db.execute(
          'CREATE TABLE IF NOT EXISTS referential_status_history '
          '(id INTEGER PRIMARY KEY AUTOINCREMENT, child_id TEXT NOT NULL, '
          'referential_id TEXT NOT NULL, item_id TEXT NOT NULL, '
          'statut INTEGER NOT NULL, changed_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_referential_history_child '
          'ON referential_status_history (child_id, referential_id)',
        );
      default:
        throw StateError('Migration manquante vers la version $version');
    }
  }

  // ─────────────── Entites ───────────────

  Future<List<Map<String, dynamic>>> _readAll(String table) async {
    final db = await _database;
    final rows = await db.query(table, columns: ['data']);
    return rows
        .map((r) => json.decode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _upsert(String table, String id, Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert(
      table,
      {'id': id, 'data': json.encode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _delete(String table, String id) async {
    final db = await _database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Child>> readChildren() async =>
      (await _readAll('children')).map(Child.fromMap).toList();
  Future<void> saveChild(Child c) => _upsert('children', c.id, c.toMap());
  Future<void> deleteChild(String id) => _delete('children', id);

  Future<List<Space>> readSpaces() async =>
      (await _readAll('spaces')).map(Space.fromMap).toList();
  Future<void> saveSpace(Space s) => _upsert('spaces', s.id, s.toMap());
  Future<void> deleteSpace(String id) => _delete('spaces', id);

  Future<List<ActivityType>> readActivityTypes() async =>
      (await _readAll('activity_types')).map(ActivityType.fromMap).toList();
  Future<void> saveActivityType(ActivityType a) =>
      _upsert('activity_types', a.id, a.toMap());
  Future<void> deleteActivityType(String id) => _delete('activity_types', id);

  Future<List<ActivityLog>> readActivities() async =>
      (await _readAll('activities')).map(ActivityLog.fromMap).toList();
  Future<void> saveActivity(ActivityLog l) => _upsert('activities', l.id, l.toMap());
  Future<void> deleteActivity(String id) => _delete('activities', id);

  // ─────────────── Annees scolaires archivees ───────────────

  Future<List<SchoolYearArchive>> readArchives() async =>
      (await _readAll('archives')).map(SchoolYearArchive.fromMap).toList();

  Future<void> saveArchive(SchoolYearArchive a) =>
      _upsert('archives', a.id, a.toMap());

  Future<void> deleteArchive(String id) => _delete('archives', id);

  /// Supprime toutes les lignes d'une table entite.
  Future<void> clearTable(String table) async {
    final db = await _database;
    await db.delete(table);
  }

  /// Supprime en une transaction la fiche d'un eleve et son suivi des sons
  /// courant. Comme pour les observations, l'historique des sons
  /// ([sons_history]) n'est volontairement pas efface : c'est une trace,
  /// pas un etat courant.
  Future<void> deleteChildCascade(String childId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('children', where: 'id = ?', whereArgs: [childId]);
      await txn.delete('sons', where: 'child_id = ?', whereArgs: [childId]);
      await txn.delete('referential_status', where: 'child_id = ?', whereArgs: [childId]);
    });
  }

  // ─────────────── Sons ───────────────

  Future<Map<String, Map<String, SonStatut>>> readSons() async {
    final db = await _database;
    final rows = await db.query('sons');
    final result = <String, Map<String, SonStatut>>{};
    for (final row in rows) {
      final childId = row['child_id'] as String;
      result.putIfAbsent(childId, () => {})[row['son'] as String] =
          SonStatut.fromCode(row['statut'] as int);
    }
    return result;
  }

  Future<void> setSon(String childId, String son, SonStatut statut) async {
    final db = await _database;
    if (statut == SonStatut.nonAcquis) {
      // Non acquis est l'etat par defaut : on ne stocke que ce qui a ete
      // effectivement pointe.
      await db.delete('sons',
          where: 'child_id = ? AND son = ?', whereArgs: [childId, son]);
      return;
    }
    await db.insert(
      'sons',
      {'child_id': childId, 'son': son, 'statut': statut.code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearSons(String childId) async {
    final db = await _database;
    await db.delete('sons', where: 'child_id = ?', whereArgs: [childId]);
  }

  /// Ajoute un point a l'historique d'un son. Append-only : n'ecrase jamais
  /// les points precedents, contrairement a [setSon].
  Future<void> recordSonHistory(
    String childId,
    String son,
    SonStatut statut,
    DateTime at,
  ) async {
    final db = await _database;
    await db.insert('sons_history', {
      'child_id': childId,
      'son': son,
      'statut': statut.code,
      'changed_at': at.toIso8601String(),
    });
  }

  /// Historique complet d'un eleve, du plus ancien au plus recent.
  Future<List<SonHistoryEntry>> readSonHistory(String childId) async {
    final db = await _database;
    final rows = await db.query(
      'sons_history',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'changed_at ASC',
    );
    return rows
        .map((r) => SonHistoryEntry(
              son: r['son'] as String,
              statut: SonStatut.fromCode(r['statut']),
              changedAt: DateTime.parse(r['changed_at'] as String),
            ))
        .toList();
  }

  Future<void> clearAllSons() async {
    final db = await _database;
    await db.delete('sons');
  }

  // ─────────────── Referentiels personnalises ───────────────

  Future<List<Referential>> readReferentials() async =>
      (await _readAll('referentials')).map(Referential.fromMap).toList();

  Future<void> saveReferential(Referential r) => _upsert('referentials', r.id, r.toMap());

  /// Supprime le referentiel, le statut de tous les eleves qui s'y rapporte,
  /// et son historique : contrairement a la suppression d'un eleve, il n'y a
  /// ici plus rien a retracer une fois le referentiel lui-meme parti.
  Future<void> deleteReferentialCascade(String referentialId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('referentials', where: 'id = ?', whereArgs: [referentialId]);
      await txn.delete('referential_status',
          where: 'referential_id = ?', whereArgs: [referentialId]);
      await txn.delete('referential_status_history',
          where: 'referential_id = ?', whereArgs: [referentialId]);
    });
  }

  /// Statuts de tous les eleves, pour tous les referentiels : referentialId ->
  /// childId -> itemId -> statut. Charge en une fois au demarrage, comme
  /// [readSons] : les volumes en jeu ne justifient pas une lecture paresseuse.
  Future<Map<String, Map<String, Map<String, SonStatut>>>> readAllReferentialStatuses() async {
    final db = await _database;
    final rows = await db.query('referential_status');
    final result = <String, Map<String, Map<String, SonStatut>>>{};
    for (final row in rows) {
      final referentialId = row['referential_id'] as String;
      final childId = row['child_id'] as String;
      final itemId = row['item_id'] as String;
      result
          .putIfAbsent(referentialId, () => {})
          .putIfAbsent(childId, () => {})[itemId] = SonStatut.fromCode(row['statut']);
    }
    return result;
  }

  Future<void> setReferentialItemStatus(
    String childId,
    String referentialId,
    String itemId,
    SonStatut statut,
  ) async {
    final db = await _database;
    if (statut == SonStatut.nonAcquis) {
      await db.delete(
        'referential_status',
        where: 'child_id = ? AND referential_id = ? AND item_id = ?',
        whereArgs: [childId, referentialId, itemId],
      );
      return;
    }
    await db.insert(
      'referential_status',
      {
        'child_id': childId,
        'referential_id': referentialId,
        'item_id': itemId,
        'statut': statut.code,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Efface le statut d'un eleve pour un referentiel donne (restauration).
  Future<void> clearReferentialStatusForChild(String childId, String referentialId) async {
    final db = await _database;
    await db.delete(
      'referential_status',
      where: 'child_id = ? AND referential_id = ?',
      whereArgs: [childId, referentialId],
    );
  }

  /// Efface le statut de tous les eleves, pour tous les referentiels :
  /// utilise a la cloture de l'annee scolaire, les referentiels eux-memes
  /// (comme les ateliers) se reutilisant d'une annee sur l'autre.
  Future<void> clearAllReferentialStatuses() async {
    final db = await _database;
    await db.delete('referential_status');
  }

  /// Ajoute un point a l'historique d'un item de referentiel. Append-only,
  /// comme [recordSonHistory].
  Future<void> recordReferentialHistory(
    String childId,
    String referentialId,
    String itemId,
    SonStatut statut,
    DateTime at,
  ) async {
    final db = await _database;
    await db.insert('referential_status_history', {
      'child_id': childId,
      'referential_id': referentialId,
      'item_id': itemId,
      'statut': statut.code,
      'changed_at': at.toIso8601String(),
    });
  }

  /// Historique d'un eleve pour un referentiel donne, du plus ancien au plus
  /// recent.
  Future<List<ReferentialHistoryEntry>> readReferentialHistory(
    String childId,
    String referentialId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'referential_status_history',
      where: 'child_id = ? AND referential_id = ?',
      whereArgs: [childId, referentialId],
      orderBy: 'changed_at ASC',
    );
    return rows
        .map((r) => ReferentialHistoryEntry(
              itemId: r['item_id'] as String,
              statut: SonStatut.fromCode(r['statut']),
              changedAt: DateTime.parse(r['changed_at'] as String),
            ))
        .toList();
  }

  // ─────────────── Reglages ───────────────

  Future<Map<String, String>> readSettings() async {
    final db = await _database;
    final rows = await db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─────────────── Remplacement global (restauration de sauvegarde) ───────────────

  Future<void> replaceAll({
    required ClassSettings classSettings,
    required List<Child> children,
    required List<Space> spaces,
    required List<ActivityType> activityTypes,
    required List<ActivityLog> activities,
    required List<EvaluationStatus> evaluationStatuses,
    required Map<String, Map<String, SonStatut>> sons,
  }) async {
    final db = await _database;
    // Une transaction unique : une restauration interrompue ne doit pas
    // laisser un melange de l'ancien et du nouveau jeu de donnees.
    await db.transaction((txn) async {
      for (final table in _entityTables) {
        await txn.delete(table);
      }
      await txn.delete('sons');

      for (final c in children) {
        await txn.insert('children', {'id': c.id, 'data': json.encode(c.toMap())});
      }
      for (final s in spaces) {
        await txn.insert('spaces', {'id': s.id, 'data': json.encode(s.toMap())});
      }
      for (final a in activityTypes) {
        await txn.insert('activity_types', {'id': a.id, 'data': json.encode(a.toMap())});
      }
      for (final l in activities) {
        await txn.insert('activities', {'id': l.id, 'data': json.encode(l.toMap())});
      }
      sons.forEach((childId, entries) {
        entries.forEach((son, statut) {
          if (statut == SonStatut.nonAcquis) return;
          txn.insert('sons',
              {'child_id': childId, 'son': son, 'statut': statut.code});
        });
      });

      await txn.insert('settings',
          {'key': 'class_settings', 'value': classSettings.toJson()},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('settings',
          {'key': 'evaluation_statuses', 'value': json.encode(evaluationStatuses.map((s) => s.toMap()).toList())},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Reprend les donnees encore presentes dans SharedPreferences.
  ///
  /// Les preferences ne sont volontairement pas effacees : si la migration
  /// s'averait fautive, les donnees d'origine restent recuperables.
  Future<bool> migrateFromPrefs(Map<String, String?> prefs) async {
    final settings = await readSettings();
    if (settings['migrated_from_prefs'] == 'true') return false;

    final db = await _database;
    var imported = 0;

    Future<void> importEntities(String table, String? raw) async {
      if (raw == null) return;
      final decoded = json.decode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty) continue;
        await db.insert(table, {'id': id, 'data': json.encode(map)},
            conflictAlgorithm: ConflictAlgorithm.replace);
        imported++;
      }
    }

    try {
      await importEntities('children', prefs['children']);
      await importEntities('spaces', prefs['spaces']);
      await importEntities('activity_types', prefs['activity_types']);
      await importEntities('activities', prefs['activities']);

      final sonsRaw = prefs['sons_progress'];
      if (sonsRaw != null) {
        final decoded = json.decode(sonsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final sons = entry.value;
            if (sons is! Map) continue;
            for (final sonEntry in sons.entries) {
              await setSon(entry.key as String, sonEntry.key as String,
                  SonStatut.fromCode(sonEntry.value));
            }
          }
        }
      }

      for (final key in ['class_settings', 'evaluation_statuses', 'theme_mode']) {
        final value = prefs[key];
        if (value != null) await setSetting(key, value);
      }
      final lock = prefs['biometric_lock_enabled'];
      if (lock != null) await setSetting('biometric_lock_enabled', lock);

      await setSetting('migrated_from_prefs', 'true');
      debugPrint('Migration SharedPreferences -> SQLite : $imported enregistrements.');
      return imported > 0;
    } catch (e) {
      debugPrint('Echec de la migration SharedPreferences -> SQLite : $e');
      // Pas de marqueur pose : la migration sera retentee au prochain
      // demarrage plutot que d'abandonner silencieusement les donnees.
      return false;
    }
  }
}
