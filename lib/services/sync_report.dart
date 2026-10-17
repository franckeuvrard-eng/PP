import '../data/sons_data.dart';
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

  /// Nom lisible d'un element (« Léa Martin », « Tom · Peinture (17/10) »…).
  static String describe(
          String category, String key, Object? value, Map<String, dynamic> snapshot) =>
      _label(MergeChange(category: category, key: key, kind: ChangeKind.updated,
          onLocal: true, value: value), _Names(snapshot));

  /// Titre de la categorie (« Élèves », « Observations »…).
  static String categoryTitle(String category) => _titles[category] ?? category;

  static const _fieldLabels = {
    'firstname': 'Prénom',
    'lastname': 'Nom',
    'birthdate': 'Date de naissance',
    'group': 'Groupe',
    'notes': 'Notes',
    'colorHex': 'Couleur',
    'avatarText': 'Initiales',
    'email': 'E-mail',
    'imagePath': 'Photo',
    'imageAuthorized': 'Autorisation photo',
    'childId': 'Élève',
    'activityTypeId': 'Atelier',
    'timestamp': 'Date',
    'note': 'Commentaire',
    'photoPaths': 'Photos',
    'photoCaptions': 'Légendes des photos',
    'evaluationStatusId': 'Statut',
    'audioPath': 'Note vocale',
    'name': 'Nom',
    'spaceId': 'Espace',
    'description': 'Description',
    'domaine': 'Domaine',
    'domaineId': 'Domaine',
    'objectifs': 'Objectifs',
    'isObligatory': 'Obligatoire',
    'obligatoryGroups': 'Groupes concernés',
    'iconName': 'Icône',
    'position': 'Ordre',
    'isProgression': 'Suivi de progression',
    'progressionMinStatusId': 'Seuil de progression',
    'label': 'Libellé',
    'teacher': 'Enseignant(e)',
    'atsem': 'ATSEM',
    'schoolName': 'École',
    'level': 'Niveau',
    'schoolYear': 'Année scolaire',
    'logoPath': 'Logo',
    'groups': 'Contenu',
  };

  static String fieldLabel(String field) => _fieldLabels[field] ?? field;

  /// Valeur affichable d'un champ ([field] vide : valeur simple, comme le
  /// statut d'un son ou d'une competence).
  static String formatValue(
      String category, String field, Object? v, Map<String, dynamic> snapshot) {
    if (category == 'sons_progress' || category == 'referential_status') {
      return SonStatut.fromCode(v).libelle;
    }
    if (v == null || (v is String && v.trim().isEmpty)) return '(vide)';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is List) {
      if (v.isEmpty) return '(aucun)';
      if (field == 'photoPaths') return '${v.length} photo(s)';
      if (v.every((e) => e is String || e is num)) return v.join(', ');
      return '${v.length} élément(s)';
    }
    if (v is Map) return '${v.length} élément(s)';
    final n = _Names(snapshot);
    final text = v.toString();
    switch (field) {
      case 'childId':
        return n.child(text);
      case 'activityTypeId':
        return n.activityType(text);
      case 'spaceId':
        return n.space(text);
      case 'evaluationStatusId':
      case 'progressionMinStatusId':
        return n.status(text);
      case 'imagePath':
      case 'logoPath':
      case 'audioPath':
        return 'Présente';
    }
    final d = RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text) ? DateTime.tryParse(text) : null;
    if (d != null) {
      String two(int x) => x.toString().padLeft(2, '0');
      final day = '${two(d.day)}/${two(d.month)}/${d.year}';
      return text.length > 10 ? '$day à ${two(d.hour)}:${two(d.minute)}' : day;
    }
    return text;
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
        _refs = _index(snapshot['referentials']),
        _spaces = _index(snapshot['spaces']),
        _statuses = _index(snapshot['evaluation_statuses']);

  final Map<String, Map> _children;
  final Map<String, Map> _types;
  final Map<String, Map> _refs;
  final Map<String, Map> _spaces;
  final Map<String, Map> _statuses;

  String space(String? id) => SyncReport._str(_spaces[id]?['name'], 'Espace supprimé');

  String status(String? id) => SyncReport._str(_statuses[id]?['label'], 'Statut supprimé');

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
