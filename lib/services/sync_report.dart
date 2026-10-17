import 'sync_merge.dart';

/// Compte rendu lisible d'une synchronisation, pour un appareil.
///
/// Fonctions pures : les libelles (noms d'eleves, d'ateliers…) sont retrouves
/// dans l'instantane fusionne, qui contient tout ce que les deux appareils
/// connaissent apres la synchronisation.
class SyncReportGroup {
  const SyncReportGroup({required this.title, required this.lines});

  /// « Élèves », « Observations »…
  final String title;
  final List<SyncReportLine> lines;

  int count(ChangeKind kind) => lines.where((l) => l.kind == kind).length;
}

class SyncReportLine {
  const SyncReportLine({required this.kind, required this.label, this.conflict = false});

  final ChangeKind kind;
  final String label;
  final bool conflict;
}

class SyncReport {
  const SyncReport._();

  static const _titles = {
    'children': 'Élèves',
    'activities': 'Observations',
    'activity_types': 'Ateliers',
    'spaces': 'Espaces',
    'sons_progress': 'Sons',
    'referential_status': 'Compétences',
    'referentials': 'Référentiels',
    'evaluation_statuses': 'Statuts d’évaluation',
    'sections': 'Sections',
    'class_settings': 'Réglages de la classe',
  };

  /// Groupes de changements subis par l'appareil local ([onLocal] vrai) ou
  /// par l'autre, dans l'ordre de [_titles].
  static List<SyncReportGroup> build(
    List<MergeChange> changes, {
    required bool onLocal,
    required Map<String, dynamic> snapshot,
  }) {
    final names = _Names(snapshot);
    final byCat = <String, List<SyncReportLine>>{};
    for (final c in changes) {
      if (c.onLocal != onLocal) continue;
      byCat.putIfAbsent(c.category, () => []).add(SyncReportLine(
            kind: c.kind,
            label: _label(c, names),
            conflict: c.conflict,
          ));
    }
    return [
      for (final cat in {..._titles.keys, ...byCat.keys})
        if (byCat[cat] case final lines?)
          SyncReportGroup(title: _titles[cat] ?? cat, lines: lines..sort(_byKindThenLabel)),
    ];
  }

  static int _byKindThenLabel(SyncReportLine a, SyncReportLine b) {
    final k = a.kind.index.compareTo(b.kind.index);
    return k != 0 ? k : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  static String _label(MergeChange c, _Names n) {
    final v = c.value is Map ? c.value as Map : const {};
    final parts = c.key.split('\u0000');
    switch (c.category) {
      case 'children':
        return n.childFromMap(v);
      case 'activities':
        final who = n.child(v['childId']?.toString());
        final what = n.activityType(v['activityTypeId']?.toString());
        final when = _date(v['timestamp']);
        return [who, what].join(' · ') + (when.isEmpty ? '' : ' ($when)');
      case 'activity_types':
      case 'spaces':
        return _str(v['name'], 'Sans nom');
      case 'referentials':
        return _str(v['name'], 'Sans nom');
      case 'evaluation_statuses':
        return _str(v['label'], 'Sans nom');
      case 'sons_progress':
        return parts.length >= 2 ? '${n.child(parts[0])} : son « ${parts[1]} »' : c.key;
      case 'referential_status':
        return parts.length >= 3
            ? '${n.child(parts[1])} : ${n.referential(parts[0])}'
            : c.key;
      case 'sections':
        return c.key;
      case 'class_settings':
        return 'Nom, logo, options…';
    }
    return c.key;
  }

  static String _str(Object? v, String fallback) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  static String _date(Object? iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

/// Index des libelles de l'instantane fusionne.
class _Names {
  _Names(Map<String, dynamic> snapshot)
      : _children = _index(snapshot['children']),
        _types = _index(snapshot['activity_types']),
        _refs = _index(snapshot['referentials']);

  final Map<String, Map> _children;
  final Map<String, Map> _types;
  final Map<String, Map> _refs;

  static Map<String, Map> _index(Object? list) => {
        if (list is List)
          for (final item in list)
            if (item is Map && item['id'] is String) item['id'] as String: item,
      };

  String childFromMap(Map v) {
    final name = '${v['firstname'] ?? ''} ${v['lastname'] ?? ''}'.trim();
    return name.isEmpty ? 'Élève sans nom' : name;
  }

  String child(String? id) {
    final c = _children[id];
    return c == null ? 'Élève supprimé' : childFromMap(c);
  }

  String activityType(String? id) =>
      SyncReport._str(_types[id]?['name'], 'Atelier supprimé');

  String referential(String? id) =>
      SyncReport._str(_refs[id]?['name'], 'Référentiel');
}
