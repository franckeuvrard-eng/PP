import 'dart:convert';

/// Fusion a trois voies de deux jeux de donnees (appareil local / appareil
/// distant) a partir de leur dernier etat commun (la « base »).
///
/// Fonctions pures, sans Flutter ni E/S : testables seules.
///
/// Regle, enregistrement par enregistrement :
///  - identique des deux cotes → rien a faire ;
///  - modifie ou supprime d'un seul cote depuis la base → ce changement gagne ;
///  - modifie des deux cotes → la version locale (appareil qui lance la
///    synchronisation) gagne ; une suppression ne l'emporte jamais sur une
///    modification (on ne perd pas de donnees en cas de doute) ;
///  - pas de base (premiere synchronisation, ou enregistrement apparu des deux
///    cotes depuis) → union : rien n'est supprime.
class SyncMerge {
  const SyncMerge._();

  /// Collections de la sauvegarde qui sont des listes d'objets portant un `id`.
  static const listCollections = [
    'children',
    'spaces',
    'activity_types',
    'activities',
    'evaluation_statuses',
    'referentials',
  ];

  static const _sep = '\u0000';

  /// Empreinte stable d'une valeur JSON (cles triees), sur 64 bits.
  static String hash(Object? value) {
    final text = json.encode(_canonical(value));
    var a = 0x811c9dc5;
    var b = 0x01000193 ^ 0x5bd1e995;
    for (final unit in utf8.encode(text)) {
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ unit) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return a.toRadixString(16).padLeft(8, '0') + b.toRadixString(16).padLeft(8, '0');
  }

  static Object? _canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(v[k])};
    }
    if (v is List) return v.map(_canonical).toList();
    return v;
  }

  /// Met un instantane a plat : `categorie` → (`cle` → valeur).
  static Map<String, Map<String, Object?>> flatten(Map<String, dynamic> snapshot) {
    final out = <String, Map<String, Object?>>{};

    for (final name in listCollections) {
      final records = <String, Object?>{};
      final raw = snapshot[name];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final id = item['id'];
          records[id is String && id.isNotEmpty ? id : 'h:${hash(item)}'] = item;
        }
      }
      out[name] = records;
    }

    final settings = snapshot['class_settings'];
    out['class_settings'] = {if (settings != null) 'class_settings': settings};

    final sections = snapshot['sections'];
    out['sections'] = {
      if (sections is List)
        for (final s in sections) s.toString(): s.toString(),
    };

    final sons = <String, Object?>{};
    final sonsRaw = snapshot['sons_progress'];
    if (sonsRaw is Map) {
      sonsRaw.forEach((childId, entries) {
        if (entries is! Map) return;
        entries.forEach((son, code) => sons['$childId$_sep$son'] = code);
      });
    }
    out['sons_progress'] = sons;

    final statuses = <String, Object?>{};
    final statusRaw = snapshot['referential_status'];
    if (statusRaw is Map) {
      statusRaw.forEach((refId, byChild) {
        if (byChild is! Map) return;
        byChild.forEach((childId, items) {
          if (items is! Map) return;
          items.forEach((itemId, code) =>
              statuses['$refId$_sep$childId$_sep$itemId'] = code);
        });
      });
    }
    out['referential_status'] = statuses;

    return out;
  }

  /// Inverse de [flatten] : reconstruit la forme « sauvegarde ». L'ordre des
  /// listes est celui de [order] (l'instantane local) puis les nouveautes.
  static Map<String, dynamic> unflatten(
    Map<String, Map<String, Object?>> flat, {
    required Map<String, dynamic> order,
  }) {
    final out = <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final name in listCollections) {
      final records = flat[name] ?? const {};
      final ordered = <Object?>[];
      final seen = <String>{};
      final localList = order[name];
      if (localList is List) {
        for (final item in localList) {
          if (item is! Map) continue;
          final id = item['id'];
          final key = id is String && id.isNotEmpty ? id : 'h:${hash(item)}';
          if (records.containsKey(key) && seen.add(key)) ordered.add(records[key]);
        }
      }
      for (final e in records.entries) {
        if (seen.add(e.key)) ordered.add(e.value);
      }
      out[name] = ordered;
    }

    final settings = flat['class_settings']?['class_settings'];
    if (settings != null) {
      out['class_settings'] = settings;
    } else if (order['class_settings'] != null) {
      out['class_settings'] = order['class_settings'];
    }

    final sections = flat['sections'] ?? const {};
    final orderedSections = <String>[];
    final localSections = order['sections'];
    if (localSections is List) {
      for (final s in localSections) {
        if (sections.containsKey(s.toString()) && !orderedSections.contains(s.toString())) {
          orderedSections.add(s.toString());
        }
      }
    }
    for (final k in sections.keys) {
      if (!orderedSections.contains(k)) orderedSections.add(k);
    }
    out['sections'] = orderedSections;

    final sons = <String, Map<String, Object?>>{};
    (flat['sons_progress'] ?? const {}).forEach((key, code) {
      final parts = key.split(_sep);
      sons.putIfAbsent(parts[0], () => {})[parts.sublist(1).join(_sep)] = code;
    });
    out['sons_progress'] = sons;

    final statuses = <String, Map<String, Map<String, Object?>>>{};
    (flat['referential_status'] ?? const {}).forEach((key, code) {
      final parts = key.split(_sep);
      if (parts.length < 3) return;
      statuses
          .putIfAbsent(parts[0], () => {})
          .putIfAbsent(parts[1], () => {})[parts.sublist(2).join(_sep)] = code;
    });
    out['referential_status'] = statuses;

    return out;
  }

  /// Empreintes de tous les enregistrements : sert de « base » a la
  /// prochaine synchronisation.
  static Map<String, String> fingerprints(Map<String, Map<String, Object?>> flat) => {
        for (final cat in flat.entries)
          for (final rec in cat.value.entries)
            '${cat.key}$_sep${rec.key}': hash(rec.value),
      };

  /// Fusionne [local] et [remote]. [base] vaut null a la premiere
  /// synchronisation avec cet appareil.
  ///
  /// [resolutions] : valeur choisie par l'utilisateur pour un conflit, par
  /// [MergeConflict.id]. Sans choix, la version locale l'emporte. Les conflits
  /// rencontres sont listes dans [MergeResult.conflicts] : on fusionne une
  /// premiere fois pour les presenter, puis une seconde avec les choix.
  static MergeResult merge({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    Map<String, String>? base,
    Map<String, Object?>? resolutions,
  }) {
    final l = flatten(local);
    final r = flatten(remote);
    final merged = <String, Map<String, Object?>>{};
    final stats = MergeStats();
    final conflicts = <MergeConflict>[];

    for (final cat in {...l.keys, ...r.keys}) {
      final lc = l[cat] ?? const <String, Object?>{};
      final rc = r[cat] ?? const <String, Object?>{};
      final out = <String, Object?>{};

      for (final key in {...lc.keys, ...rc.keys}) {
        final hasL = lc.containsKey(key);
        final hasR = rc.containsKey(key);
        final lh = hasL ? hash(lc[key]) : null;
        final rh = hasR ? hash(rc[key]) : null;
        if (lh == rh) {
          if (hasL) out[key] = lc[key];
          continue;
        }
        final bh = base?['$cat$_sep$key'];

        // Present des deux cotes et modifie des deux cotes (ou sans base
        // commune) : c'est a l'utilisateur de trancher. Supprime d'un cote et
        // modifie de l'autre n'en est pas un : la modification gagne.
        final conflict = hasL && hasR && (bh == null || (lh != bh && rh != bh));

        bool chosenHas;
        Object? chosen;
        if (conflict) {
          final c = MergeConflict(category: cat, key: key, local: lc[key], remote: rc[key]);
          conflicts.add(c);
          stats.conflicts++;
          chosenHas = true;
          chosen = (resolutions != null && resolutions.containsKey(c.id))
              ? resolutions[c.id]
              : lc[key];
        } else {
          // 'L' garde le local, 'R' prend le distant.
          final String winner;
          if (bh == null) {
            winner = hasL ? 'L' : 'R'; // Pas de base : union.
          } else if (lh == bh) {
            winner = 'R';
          } else if (rh == bh) {
            winner = 'L';
          } else {
            winner = hasL ? 'L' : 'R'; // Supprime d'un cote, modifie de l'autre.
          }
          chosenHas = winner == 'L' ? hasL : hasR;
          chosen = chosenHas ? (winner == 'L' ? lc[key] : rc[key]) : null;
        }
        if (chosenHas) out[key] = chosen;

        // Effet sur chaque appareil, pour le compte rendu. Valeur qui decrit
        // l'element : la nouvelle, ou l'ancienne s'il disparait.
        final targetHash = chosenHas ? hash(chosen) : null;
        if (targetHash != lh) {
          final ChangeKind kind;
          if (!hasL) {
            kind = ChangeKind.added;
            stats.addedLocally++;
          } else if (!chosenHas) {
            kind = ChangeKind.deleted;
            stats.deletedLocally++;
          } else {
            kind = ChangeKind.updated;
            stats.updatedLocally++;
          }
          stats.changes.add(MergeChange(
              category: cat, key: key, kind: kind, onLocal: true,
              value: chosenHas ? chosen : lc[key], conflict: conflict));
        }
        if (targetHash != rh) {
          final ChangeKind kind;
          if (!hasR) {
            kind = ChangeKind.added;
            stats.addedRemotely++;
          } else if (!chosenHas) {
            kind = ChangeKind.deleted;
            stats.deletedRemotely++;
          } else {
            kind = ChangeKind.updated;
            stats.updatedRemotely++;
          }
          stats.changes.add(MergeChange(
              category: cat, key: key, kind: kind, onLocal: false,
              value: chosenHas ? chosen : rc[key], conflict: conflict));
        }
      }
      merged[cat] = out;
    }

    return MergeResult(
      snapshot: unflatten(merged, order: local),
      fingerprints: fingerprints(merged),
      stats: stats,
      conflicts: conflicts,
    );
  }
}

/// Element modifie sur les deux appareils depuis leur derniere synchronisation.
class MergeConflict {
  const MergeConflict({
    required this.category,
    required this.key,
    required this.local,
    required this.remote,
  });

  final String category;
  final String key;
  final Object? local;
  final Object? remote;

  /// Cle des [SyncMerge.merge] `resolutions`.
  String get id => '$category${SyncMerge._sep}$key';

  /// Champs qui different, quand les deux versions sont des objets ; vide
  /// sinon (valeur simple : statut d'un son, d'une competence…).
  List<String> get differingFields {
    final l = local, r = remote;
    if (l is! Map || r is! Map) return const [];
    return [
      for (final f in {...l.keys, ...r.keys}.map((k) => k.toString()))
        if (SyncMerge.hash(l[f]) != SyncMerge.hash(r[f])) f,
    ];
  }

  /// Version fusionnee : pour chaque champ de [fromRemote], la valeur de
  /// l'autre appareil, sinon celle d'ici.
  Object? combine(Set<String> fromRemote) {
    final l = local, r = remote;
    if (l is! Map || r is! Map) return fromRemote.isEmpty ? l : r;
    final out = Map<String, Object?>.from(l);
    for (final f in fromRemote) {
      if (r.containsKey(f)) {
        out[f] = r[f];
      } else {
        out.remove(f);
      }
    }
    return out;
  }
}

class MergeStats {
  int addedLocally = 0;
  int updatedLocally = 0;
  int deletedLocally = 0;
  int addedRemotely = 0;
  int updatedRemotely = 0;
  int deletedRemotely = 0;
  int conflicts = 0;

  /// Detail de chaque changement, pour le compte rendu a l'utilisateur.
  final List<MergeChange> changes = [];

  int get changesLocally => addedLocally + updatedLocally + deletedLocally;
  int get changesRemotely => addedRemotely + updatedRemotely + deletedRemotely;

  Map<String, int> toMap() => {
        'addedLocally': addedLocally,
        'updatedLocally': updatedLocally,
        'deletedLocally': deletedLocally,
        'addedRemotely': addedRemotely,
        'updatedRemotely': updatedRemotely,
        'deletedRemotely': deletedRemotely,
        'conflicts': conflicts,
      };
}

enum ChangeKind { added, updated, deleted }

/// Un enregistrement ajoute, modifie ou supprime sur un des deux appareils.
class MergeChange {
  const MergeChange({
    required this.category,
    required this.key,
    required this.kind,
    required this.onLocal,
    this.value,
    this.conflict = false,
  });

  /// Categorie de [SyncMerge.flatten] (`children`, `activities`, `sons_progress`…).
  final String category;
  final String key;
  final ChangeKind kind;

  /// Vrai si le changement a lieu sur l'appareil qui lance la synchronisation.
  final bool onLocal;

  /// Nouvelle valeur, ou ancienne pour une suppression.
  final Object? value;

  /// Modifie des deux cotes : la version de l'autre appareil a ete ecartee.
  final bool conflict;

  /// Meme changement vu depuis l'autre appareil (envoye avec `/apply`).
  MergeChange flipped() => MergeChange(
      category: category, key: key, kind: kind, onLocal: !onLocal,
      value: value, conflict: conflict);

  Map<String, dynamic> toMap() => {
        'category': category,
        'key': key,
        'kind': kind.name,
        'onLocal': onLocal,
        'value': value,
        'conflict': conflict,
      };

  static MergeChange? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = ChangeKind.values.where((k) => k.name == raw['kind']).firstOrNull;
    if (kind == null || raw['category'] is! String || raw['key'] is! String) return null;
    return MergeChange(
      category: raw['category'] as String,
      key: raw['key'] as String,
      kind: kind,
      onLocal: raw['onLocal'] == true,
      value: raw['value'],
      conflict: raw['conflict'] == true,
    );
  }
}

class MergeResult {
  const MergeResult({
    required this.snapshot,
    required this.fingerprints,
    required this.stats,
    this.conflicts = const [],
  });

  final Map<String, dynamic> snapshot;
  final Map<String, String> fingerprints;
  final MergeStats stats;
  final List<MergeConflict> conflicts;
}
