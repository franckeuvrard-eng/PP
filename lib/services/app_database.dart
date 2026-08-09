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
  static const _dbName = 'petitpas.db';
  static const _schemaVersion = 1;

  /// Tables « entite » : cle primaire texte + JSON.
  static const _entityTables = [
    'children',
    'spaces',
    'activity_types',
    'activities',
  ];

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
      p.join(dir, _dbName),
      version: _schemaVersion,
      onCreate: (db, version) async {
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
      },
    );
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

  /// Supprime toutes les lignes d'une table entite.
  Future<void> clearTable(String table) async {
    final db = await _database;
    await db.delete(table);
  }

  /// Supprime en une transaction les observations d'un eleve et son suivi des
  /// sons : sans cela un plantage entre les deux laisserait des orphelins.
  Future<void> deleteChildCascade(String childId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('children', where: 'id = ?', whereArgs: [childId]);
      await txn.delete('sons', where: 'child_id = ?', whereArgs: [childId]);
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

  Future<void> clearAllSons() async {
    final db = await _database;
    await db.delete('sons');
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
