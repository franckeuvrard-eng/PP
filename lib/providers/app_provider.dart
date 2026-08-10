import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/activity.dart';
import '../models/class_settings.dart';
import '../models/space.dart';
import '../models/evaluation_status.dart';
import '../models/school_year_archive.dart';
import '../data/eduscol_data.dart';
import '../data/sons_data.dart';
import '../services/app_database.dart';
import '../services/icloud_backup_service.dart';

class AppStateProvider extends ChangeNotifier {
  /// Recalcule les index avant de prevenir les ecrans.
  ///
  /// Toutes les mutations passent par ici : c'est la seule garantie que les
  /// index ne divergent pas des listes.
  void _notify() {
    _reindex();
    notifyListeners();
  }

  ClassSettings _classSettings = ClassSettings(
    name: "Classe Petite Section (PS)",
    teacher: "Mme Dupont",
    level: "PS",
    schoolYear: "2026-2027",
  );

  List<Child> _children = [
    Child(id: "child_1", firstname: "Léo", lastname: "Martin", birthdate: "2023-04-12", group: "Groupe Rouge", notes: "Allergie noisettes", colorHex: "#4E9F3D", avatarText: "LM", email: "parents.leo@example.com"),
    Child(id: "child_2", firstname: "Emma", lastname: "Petit", birthdate: "2023-07-22", group: "Groupe Bleu", notes: "Doudou lapin pour la sieste", colorHex: "#FF7043", avatarText: "EP", email: "parents.emma@example.com"),
    Child(id: "child_3", firstname: "Lucas", lastname: "Bernard", birthdate: "2023-02-18", group: "Groupe Rouge", notes: "", colorHex: "#7E57C2", avatarText: "LB", email: "parents.lucas@example.com"),
    Child(id: "child_4", firstname: "Chloé", lastname: "Dubois", birthdate: "2023-09-05", group: "Groupe Jaune", notes: "Lunettes de vue", colorHex: "#FFA726", avatarText: "CD", email: "parents.chloe@example.com"),
  ];

  List<Space> _spaces = [
    Space(id: 'space_1', name: 'Coin Arts Visuels', colorHex: '#FF7043', iconName: 'palette', description: 'Peinture, dessin, collages'),
    Space(id: 'space_2', name: 'Espace Motricité', colorHex: '#4E9F3D', iconName: 'fitness_center', description: 'Parcours, jeux d\'opposition, danse'),
    Space(id: 'space_3', name: 'Coin Lecture', colorHex: '#7E57C2', iconName: 'menu_book', description: 'Albums, contes, langage oral'),
    Space(id: 'space_4', name: 'Coin Mathématiques', colorHex: '#FFA726', iconName: 'calculate', description: 'Tri, dénombrement, logique'),
    Space(id: 'space_5', name: 'Coin Écoute & Musique', colorHex: '#42A5F5', iconName: 'music_note', description: 'Instruments, comptines, écoute'),
    Space(id: 'space_6', name: 'Coin Jeux & Construction', colorHex: '#8D6E63', iconName: 'extension', description: 'Puzzles, kapla, jeux de société'),
  ];

  List<ActivityType> _activityTypes = [
    ActivityType(id: 'act_1', name: 'Peinture Libre', spaceId: 'space_1', colorHex: '#FF7043', description: 'Peinture, dessin libre ou dirigé, collages.', domaine: 'Agir, s\'exprimer à travers les activités artistiques', objectifs: []),
    ActivityType(id: 'act_2', name: 'Parcours Gymnique', spaceId: 'space_2', colorHex: '#4E9F3D', description: 'Parcours gymnique, lancer, jeux d\'opposition, danse.', domaine: 'Agir, s\'exprimer à travers l\'activité physique', objectifs: []),
    ActivityType(id: 'act_3', name: 'Lecture & Contes', spaceId: 'space_3', colorHex: '#7E57C2', description: 'Écoute de contes, manipulation d\'albums, langage oral.', domaine: 'Mobiliser le langage dans toutes ses dimensions', objectifs: []),
    ActivityType(id: 'act_4', name: 'Graphisme & Tracés', spaceId: 'space_1', colorHex: '#FFA726', description: 'Exercices de motricité fine, tracés de lignes, ronds.', domaine: 'Mobiliser le langage dans toutes ses dimensions', objectifs: []),
    ActivityType(id: 'act_5', name: 'Tri & Dénombrement', spaceId: 'space_4', colorHex: '#00BCD4', description: 'Classer, trier, dénombrer de petites collections.', domaine: 'Acquérir les premiers outils mathématiques', objectifs: []),
    ActivityType(id: 'act_6', name: 'Comptines & Chansons', spaceId: 'space_5', colorHex: '#E91E63', description: 'Apprentissage de comptines, instruments de percussion.', domaine: 'Agir, s\'exprimer à travers les activités artistiques', objectifs: []),
  ];

  List<ActivityLog> _activities = [
    ActivityLog(
      id: "log_1",
      childId: "child_1",
      activityTypeId: "act_1",
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      note: "A mélangé du bleu et du jaune pour créer du vert !",
      evaluationStatusId: "acquis",
    ),
    ActivityLog(
      id: "log_2",
      childId: "child_2",
      activityTypeId: "act_2",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      note: "A franchi la poutre d'équilibre sans aide.",
      evaluationStatusId: "en_cours",
    ),
  ];

  List<EvaluationStatus> _evaluationStatuses =
      List<EvaluationStatus>.from(EvaluationStatus.defaults);



  /// Sections / groupes de la classe.
  ///
  /// Le groupe etait auparavant un champ libre saisi sur chaque fiche eleve :
  /// une faute de frappe creait une section fantome, qui reapparaissait dans le
  /// ciblage des ateliers obligatoires.
  List<String> _sections = ['TPS', 'PS', 'MS', 'GS'];

  ThemeMode _themeMode = ThemeMode.system;

  /// Verrouillage de l'application par FaceID / code a l'ouverture.
  bool _biometricLockEnabled = true;

  /// Recopie des sauvegardes automatiques vers iCloud Drive.
  ///
  /// Active par defaut : sans elle, perdre l'iPad revient a perdre l'annee,
  /// l'export ZIP manuel etant le seul filet restant.
  bool _icloudSyncEnabled = true;

  bool _isLoaded = false;

  /// Vrai si `_load()` s'est termine en erreur.
  ///
  /// L'application demarre quand meme, mais **sans presenter la classe
  /// d'exemple des initialiseurs de champs** : une base illisible affichait
  /// jusqu'ici quatre eleves fictifs indiscernables de vraies donnees, et les
  /// persistait des la premiere modification.
  bool _loadFailed = false;

  final AppDatabase _db;

  /// Suivi « Analyse des sons » : idEleve -> son -> statut.
  ///
  /// Les sons absents valent [SonStatut.nonAcquis], on ne stocke donc que ce
  /// qui a ete effectivement pointe par l'enseignant.
  Map<String, Map<String, SonStatut>> _sonsProgress = {};

  String? _docsDirPath;

  // ─── Index de consultation ───
  //
  // Les ecrans resolvaient un eleve, un atelier ou un espace par firstWhere a
  // chaque reconstruction, et recomptaient les observations par eleve de la
  // meme facon : sur une annee scolaire cela represente des dizaines de
  // milliers d'iterations par image affichee. Ces tables sont recalculees a
  // chaque modification, soit bien plus rarement qu'on ne les consulte.
  Map<String, Child> _childById = {};
  Map<String, ActivityType> _typeById = {};
  Map<String, Space> _spaceById = {};
  Map<String, List<ActivityLog>> _logsByChild = {};
  Map<String, List<ActivityLog>> _logsByType = {};

  void _reindex() {
    _childById = {for (final c in _children) c.id: c};
    _typeById = {for (final t in _activityTypes) t.id: t};
    _spaceById = {for (final s in _spaces) s.id: s};

    _logsByChild = {};
    _logsByType = {};
    for (final log in _activities) {
      (_logsByChild[log.childId] ??= []).add(log);
      (_logsByType[log.activityTypeId] ??= []).add(log);
    }
  }

  /// Eleve correspondant a un identifiant, ou null.
  Child? childById(String? id) => id == null ? null : _childById[id];

  /// Atelier correspondant a un identifiant, ou null.
  ActivityType? activityTypeById(String? id) => id == null ? null : _typeById[id];

  /// Espace correspondant a un identifiant, ou null.
  Space? spaceById(String? id) => id == null ? null : _spaceById[id];

  /// Observations d'un eleve, de la plus recente a la plus ancienne.
  List<ActivityLog> activitiesForChild(String childId) =>
      List.unmodifiable(_logsByChild[childId] ?? const []);

  /// Observations rattachees a un atelier.
  List<ActivityLog> activitiesForType(String typeId) =>
      List.unmodifiable(_logsByType[typeId] ?? const []);

  /// Nombre d'observations d'un eleve sur une journee donnee.
  int activityCountForChildOn(String childId, DateTime day) {
    final logs = _logsByChild[childId];
    if (logs == null) return 0;
    var count = 0;
    for (final l in logs) {
      if (l.timestamp.year == day.year &&
          l.timestamp.month == day.month &&
          l.timestamp.day == day.day) {
        count++;
      }
    }
    return count;
  }

  /// Nombre total d'observations d'un eleve.
  int activityCountForChild(String childId) => _logsByChild[childId]?.length ?? 0;

  /// [database] et [documentsPath] ne servent qu'aux tests, qui ont besoin
  /// d'une base isolee et ne peuvent pas appeler `getApplicationDocumentsDirectory()`
  /// (le plugin path_provider n'existe pas hors application). Les valeurs par
  /// defaut laissent le comportement de production inchange.
  AppStateProvider({
    AppDatabase? database,
    String? documentsPath,
    bool autoLoad = true,
  }) : _db = database ?? AppDatabase() {
    _docsDirPath = documentsPath;
    if (autoLoad) unawaited(_load());
  }

  /// Relit toutes les donnees. Sert au demarrage, aux tests, et au bouton
  /// « Reessayer » propose quand [loadFailed] est vrai.
  Future<void> initialize() => _load();

  Map<String, Map<String, int>> _sonsProgressAsMap() {
    return _sonsProgress.map(
      (childId, sons) => MapEntry(
        childId,
        sons.map((son, statut) => MapEntry(son, statut.code)),
      ),
    );
  }

  ClassSettings get classSettings => _classSettings;
  List<Child> get children => List.unmodifiable(_children);
  List<Space> get spaces => List.unmodifiable(_spaces);
  List<ActivityType> get activityTypes => List.unmodifiable(_activityTypes);
  List<ActivityLog> get activities => List.unmodifiable(_activities);
  List<EvaluationStatus> get evaluationStatuses => List.unmodifiable(_evaluationStatuses);

  /// Niveau correspondant a un identifiant, ou null s'il a ete supprime.
  EvaluationStatus? statusById(String? id) {
    if (id == null) return null;
    for (final s in _evaluationStatuses) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Libelle affichable d'une observation, robuste a la suppression du niveau.
  String? statusLabel(ActivityLog log) =>
      statusById(log.evaluationStatusId)?.label ?? log.legacyStatusLabel;
  List<String> get sections => List.unmodifiable(_sections);

  void setSections(List<String> sections) {
    final cleaned = <String>[];
    for (final s in sections.map((s) => s.trim())) {
      if (s.isNotEmpty && !cleaned.contains(s)) cleaned.add(s);
    }
    _sections = cleaned;
    _write(_db.setSetting('sections', json.encode(_sections)));
    _notify();
  }

  /// Renomme une section et reporte le changement sur les eleves et les
  /// ateliers concernes, pour ne pas laisser de references orphelines.
  void renameSection(String from, String to) {
    final target = to.trim();
    if (target.isEmpty || from == target) return;

    _sections = [
      for (final s in _sections) if (s == from) target else s,
    ];

    for (var i = 0; i < _children.length; i++) {
      final c = _children[i];
      if (c.group != from) continue;
      final updated = c.copyWith(group: target);
      _children[i] = updated;
      _write(_db.saveChild(updated));
    }

    for (var i = 0; i < _activityTypes.length; i++) {
      final a = _activityTypes[i];
      if (!a.obligatoryGroups.contains(from)) continue;
      final updated = a.copyWith(
        obligatoryGroups: [for (final g in a.obligatoryGroups) if (g == from) target else g],
      );
      _activityTypes[i] = updated;
      _write(_db.saveActivityType(updated));
    }

    _write(_db.setSetting('sections', json.encode(_sections)));
    _notify();
  }

  /// Nombre d'eleves rattaches a une section, pour avertir avant suppression.
  int childCountInSection(String section) =>
      _children.where((c) => c.group == section).length;
  ThemeMode get themeMode => _themeMode;
  bool get biometricLockEnabled => _biometricLockEnabled;
  bool get icloudSyncEnabled => _icloudSyncEnabled;

  /// Vrai si les donnees n'ont pas pu etre relues : la classe affichee est
  /// vide, et rien ne doit etre saisi avant une restauration.
  bool get loadFailed => _loadFailed;

  /// Vrai une fois les preferences relues du disque.
  ///
  /// L'ecran de verrouillage doit attendre ce signal : autrement il lirait
  /// les valeurs par defaut et demanderait Face ID a quelqu'un qui l'a
  /// justement desactive.
  bool get isLoaded => _isLoaded;

  void setBiometricLockEnabled(bool enabled) {
    _biometricLockEnabled = enabled;
    _write(_db.setSetting('biometric_lock_enabled', enabled.toString()));
    _notify();
  }

  /// Statut d'un son pour un eleve. Non renseigne = non acquis.
  SonStatut sonStatut(String childId, String son) =>
      _sonsProgress[childId]?[son] ?? SonStatut.nonAcquis;

  /// Tous les sons pointes d'un eleve (les autres sont non acquis).
  Map<String, SonStatut> sonsOf(String childId) =>
      Map.unmodifiable(_sonsProgress[childId] ?? const {});

  /// Fait progresser un son : non acquis -> en cours -> acquis.
  void cycleSonStatut(String childId, String son) => _setSon(childId, son, sonStatut(childId, son).suivant);

  /// Fait reculer un son d'un cran. Reserve a l'appui long : un simple appui
  /// de trop ne doit pas effacer un acquis.
  void reculeSonStatut(String childId, String son) => _setSon(childId, son, sonStatut(childId, son).precedent);

  void _setSon(String childId, String son, SonStatut next) {
    final sons = _sonsProgress.putIfAbsent(childId, () => {});
    if (next == SonStatut.nonAcquis) {
      sons.remove(son);
      if (sons.isEmpty) _sonsProgress.remove(childId);
    } else {
      sons[son] = next;
    }
    _write(_db.setSon(childId, son, next));
    _notify();
  }

  /// Remet tous les sons d'un eleve a non acquis.
  void resetSons(String childId) {
    if (_sonsProgress.remove(childId) == null) return;
    _write(_db.clearSons(childId));
    _notify();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _write(_db.setSetting('theme_mode', _themeModeToString(mode)));
    _notify();
  }

  /// Les mutations restent synchrones pour l'interface : l'ecriture en base
  /// part en arriere-plan. On journalise les echecs plutot que de laisser
  /// remonter une exception asynchrone non capturee, qui ferait crasher
  /// l'application pour une simple ecriture manquee.
  void _write(Future<void> operation) {
    operation.catchError(
      (Object e) => debugPrint('Echec d\'ecriture en base : $e'),
    );
  }

  Future<void> _load() async {
    _loadFailed = false;
    try {
      _docsDirPath ??= (await getApplicationDocumentsDirectory()).path;

      // Reprise unique des donnees de l'ancienne version. Les preferences ne
      // sont pas effacees : elles restent un recours si la migration s'averait
      // fautive.
      final prefs = await SharedPreferences.getInstance();
      await _db.migrateFromPrefs({
        'children': prefs.getString('children'),
        'spaces': prefs.getString('spaces'),
        'activity_types': prefs.getString('activity_types'),
        'activities': prefs.getString('activities'),
        'sons_progress': prefs.getString('sons_progress'),
        'class_settings': prefs.getString('class_settings'),
        'evaluation_statuses': prefs.getString('evaluation_statuses'),
        'theme_mode': prefs.getString('theme_mode'),
        'biometric_lock_enabled': prefs.containsKey('biometric_lock_enabled')
            ? prefs.getBool('biometric_lock_enabled').toString()
            : null,
      });

      final children = await _db.readChildren();
      final spaces = await _db.readSpaces();
      final types = await _db.readActivityTypes();
      final activities = await _db.readActivities();
      final settings = await _db.readSettings();

      // Premier demarrage sans aucune donnee : on conserve les espaces et
      // ateliers d'exemple definis a la construction, sinon l'application
      // s'ouvrirait entierement vide.
      final isFirstRun = settings['class_settings'] == null &&
          children.isEmpty &&
          spaces.isEmpty &&
          types.isEmpty &&
          activities.isEmpty;
      if (isFirstRun) {
        await _seedInitialData();
      } else {
        _children = children;
        _spaces = spaces;
        _activityTypes = types;
        _activities = activities;
        _sonsProgress = await _db.readSons();

        final settingsJson = settings['class_settings'];
        if (settingsJson != null) {
          _classSettings = ClassSettings.fromJson(settingsJson);
        }
        final sectionsJson = settings['sections'];
        if (sectionsJson != null) {
          _sections = List<String>.from(json.decode(sectionsJson));
        } else {
          // Premiere ouverture apres la mise a jour : on reprend les groupes
          // deja saisis sur les fiches eleves plutot que d'imposer une liste.
          final existing = children
              .map((c) => c.group)
              .whereType<String>()
              .where((g) => g.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (existing.isNotEmpty) _sections = existing;
          await _db.setSetting('sections', json.encode(_sections));
        }

        final statusesJson = settings['evaluation_statuses'];
        if (statusesJson != null) {
          _evaluationStatuses = _decodeEvaluationStatuses(statusesJson);
          // Reecrit au format objet si la valeur lue etait l'ancienne liste de
          // libelles, pour ne pas la redecoder a chaque demarrage.
          final decoded = json.decode(statusesJson);
          if (decoded is List && decoded.any((e) => e is String)) {
            await _db.setSetting('evaluation_statuses',
                json.encode(_evaluationStatuses.map((s) => s.toMap()).toList()));
          }
        }
        _biometricLockEnabled = settings['biometric_lock_enabled'] != 'false';
        _icloudSyncEnabled = settings['icloud_sync_enabled'] != 'false';
        switch (settings['theme_mode']) {
          case 'light':
            _themeMode = ThemeMode.light;
          case 'dark':
            _themeMode = ThemeMode.dark;
          default:
            _themeMode = ThemeMode.system;
        }
      }

      _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _migrateStatusLabels();
      await _migrateDomainIds();

      // Entretien en arriere-plan : ni l'un ni l'autre ne doit retarder
      // l'affichage de l'application.
      unawaited(_maybeAutoBackup(settings['last_auto_backup']));
      unawaited(purgeOrphanPhotos());
    } catch (e) {
      debugPrint('Erreur au chargement des donnees : $e');
      // L'application doit demarrer plutot que rester bloquee sur l'ecran
      // d'attente : l'enseignante a besoin d'atteindre la restauration.
      // En revanche elle ne doit surtout pas voir la classe d'exemple des
      // initialiseurs de champs, qu'elle prendrait pour ses vraies donnees et
      // qui serait persistee des la premiere modification.
      _loadFailed = true;
      _children = [];
      _activities = [];
      _sonsProgress = {};
    }
    _isLoaded = true;
    _notify();
  }

  /// Ecrit en base le jeu de donnees d'exemple present en memoire.
  Future<void> _seedInitialData() async {
    await _db.replaceAll(
      classSettings: _classSettings,
      children: _children,
      spaces: _spaces,
      activityTypes: _activityTypes,
      activities: _activities,
      evaluationStatuses: _evaluationStatuses,
      sons: _sonsProgress,
    );
  }

  static String _themeModeToString(ThemeMode mode) {
    if (mode == ThemeMode.light) return 'light';
    if (mode == ThemeMode.dark) return 'dark';
    return 'system';
  }


  // ─── SAUVEGARDE AUTOMATIQUE & ENTRETIEN DU STOCKAGE ───

  static const int _maxAutoBackups = 5;

  /// Repertoire des sauvegardes automatiques, dans les documents de
  /// l'application : elles survivent ainsi a un redemarrage et sont reprises
  /// par la sauvegarde iCloud/iTunes de l'appareil.
  Future<Directory> _autoBackupDir() async {
    _docsDirPath ??= (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$_docsDirPath/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Ecrit une sauvegarde JSON horodatee et ne conserve que les plus recentes.
  ///
  /// Ne contient pas les photos : l'objectif est de proteger le travail de
  /// saisie sans saturer le stockage de l'appareil. L'export ZIP manuel reste
  /// la sauvegarde complete.
  Future<void> _writeAutoBackup() async {
    try {
      final dir = await _autoBackupDir();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/auto_$stamp.json');
      await file.writeAsString(json.encode({
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'class_settings': _classSettings.toMap(),
        'children': _children.map((c) => c.toMap()).toList(),
        'spaces': _spaces.map((s) => s.toMap()).toList(),
        'activity_types': _activityTypes.map((a) => a.toMap()).toList(),
        'activities': _activities.map((l) => l.toMap()).toList(),
        'evaluation_statuses': _evaluationStatuses.map((s) => s.toMap()).toList(),
        'sections': _sections,
        'sons_progress': _sonsProgressAsMap(),
      }));

      final backups = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in backups.skip(_maxAutoBackups)) {
        await old.delete();
      }
      await _db.setSetting('last_auto_backup', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Echec de la sauvegarde automatique : $e');
      return;
    }
    // Apres l'ecriture locale seulement : iCloud est une copie de ce qui est
    // deja sur le disque, un echec de televersement ne doit rien annuler.
    if (_icloudSyncEnabled) await syncToICloud();
  }

  /// Sauvegarde au plus une fois par jour, au demarrage.
  Future<void> _maybeAutoBackup(String? lastIso) async {
    if (_children.isEmpty && _activities.isEmpty) return;
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) {
      return;
    }
    await _writeAutoBackup();
  }

  /// Sauvegardes automatiques disponibles, de la plus recente a la plus ancienne.
  Future<List<File>> listAutoBackups() async {
    final dir = await _autoBackupDir();
    return dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Restaure une sauvegarde automatique (donnees seules, sans les photos).
  Future<bool> restoreAutoBackup(File backup) async {
    try {
      final data = json.decode(await backup.readAsString()) as Map<String, dynamic>;
      _classSettings = ClassSettings.fromMap(data['class_settings']);
      _children = (data['children'] as List).map((c) => Child.fromMap(c)).toList();
      _spaces = (data['spaces'] as List? ?? []).map((s) => Space.fromMap(s)).toList();
      _activityTypes =
          (data['activity_types'] as List).map((a) => ActivityType.fromMap(a)).toList();
      _activities = (data['activities'] as List).map((l) => ActivityLog.fromMap(l)).toList();
      _evaluationStatuses = _decodeEvaluationStatuses(json.encode(data['evaluation_statuses'] ?? []));
      final sons = data['sons_progress'];
      _sonsProgress = sons is Map
          ? sons.map((childId, entries) => MapEntry(
                childId as String,
                (entries as Map).map(
                    (son, code) => MapEntry(son as String, SonStatut.fromCode(code))),
              ))
          : {};
      await _db.replaceAll(
        classSettings: _classSettings,
        children: _children,
        spaces: _spaces,
        activityTypes: _activityTypes,
        activities: _activities,
        evaluationStatuses: _evaluationStatuses,
        sons: _sonsProgress,
      );
      _notify();
      return true;
    } catch (e) {
      debugPrint('Echec de la restauration automatique : $e');
      return false;
    }
  }

  // ─── COPIE ICLOUD DES SAUVEGARDES AUTOMATIQUES ───

  /// Vrai si l'appareil peut atteindre le conteneur iCloud de l'application.
  ///
  /// Faux hors iOS, sans compte iCloud, ou si iCloud Drive est desactive dans
  /// les reglages du systeme : l'interface doit alors le dire plutot que de
  /// laisser croire a une sauvegarde distante inexistante.
  Future<bool> isICloudAvailable() => ICloudBackupService.isAvailable();

  /// Televerse les sauvegardes locales manquantes et rend leur nombre.
  Future<int> syncToICloud() async {
    final local = await listAutoBackups();
    return ICloudBackupService.push(
      local.map((f) => f.path).toList(),
      keep: _maxAutoBackups,
    );
  }

  /// Sauvegardes disponibles sur iCloud, y compris celles deposees par un
  /// autre appareil et pas encore rapatriees sur celui-ci.
  Future<List<ICloudBackup>> listICloudBackups() => ICloudBackupService.list();

  /// Restaure une sauvegarde iCloud : telechargement puis relecture par le
  /// meme chemin que les sauvegardes locales, le format etant identique.
  Future<bool> restoreICloudBackup(String name) async {
    File? local;
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await ICloudBackupService.pull(name, '${tempDir.path}/$name');
      if (path == null) return false;
      local = File(path);
      return await restoreAutoBackup(local);
    } catch (e) {
      debugPrint('Echec de la restauration iCloud : $e');
      return false;
    } finally {
      if (local != null && await local.exists()) {
        try {
          await local.delete();
        } catch (_) {
          // Fichier temporaire : son maintien ne compromet pas la restauration.
        }
      }
    }
  }

  Future<void> setICloudSyncEnabled(bool enabled) async {
    _icloudSyncEnabled = enabled;
    await _db.setSetting('icloud_sync_enabled', enabled.toString());
    _notify();
    // Reactiver la synchronisation doit rattraper les sauvegardes ecrites
    // pendant qu'elle etait coupee, sans attendre le prochain demarrage.
    if (enabled) await syncToICloud();
  }

  // ─── FIN D'ANNEE SCOLAIRE ───

  Future<Directory> _archivesDir() async {
    _docsDirPath ??= (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$_docsDirPath/archives');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Annees archivees, de la plus recente a la plus ancienne.
  Future<List<SchoolYearArchive>> listArchives() async {
    final archives = await _db.readArchives();
    archives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return archives;
  }

  /// Fichier ZIP d'une archive, ou null s'il a disparu du disque.
  Future<File?> archiveFile(SchoolYearArchive archive) async {
    final file = File('${(await _archivesDir()).path}/${archive.fileName}');
    return await file.exists() ? file : null;
  }

  Future<bool> shareArchive(SchoolYearArchive archive) async {
    final file = await archiveFile(archive);
    if (file == null) return false;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'Archive PetitPas ${archive.schoolYear}',
    );
    return true;
  }

  /// Supprime une archive, fichier compris. Irreversible.
  Future<void> deleteArchive(SchoolYearArchive archive) async {
    final file = await archiveFile(archive);
    if (file != null) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Suppression du fichier d\'archive impossible : $e');
      }
    }
    await _db.deleteArchive(archive.id);
    _notify();
  }

  /// Archive l'annee en cours puis repart sur une classe vide.
  ///
  /// Efface les eleves, leurs observations et leur suivi des sons. Conserve
  /// espaces, ateliers, niveaux d'evaluation, groupes et reglages, qui se
  /// reutilisent d'une annee sur l'autre.
  ///
  /// Rend null — **sans avoir rien efface** — si l'archive n'a pas pu etre
  /// ecrite : c'est la seule protection contre un stockage plein, et il vaut
  /// mieux une annee non cloturee qu'une annee perdue.
  Future<SchoolYearArchive?> startNewSchoolYear({required String nouvelleAnnee}) async {
    final anneeArchivee = _classSettings.schoolYear;
    final childCount = _children.length;
    final activityCount = _activities.length;

    SchoolYearArchive archive;
    try {
      final bytes = await _buildBackupArchiveBytes();
      final dir = await _archivesDir();
      final stamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName =
          'petitpas_${anneeArchivee.replaceAll(RegExp(r'[^0-9A-Za-z-]'), '_')}_$stamp.zip';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Relecture du disque plutot que confiance dans l'ecriture : un
      // stockage sature peut rendre un fichier tronque sans lever.
      final taille = await file.exists() ? await file.length() : 0;
      if (taille == 0) throw Exception('Archive absente ou vide apres ecriture');

      archive = SchoolYearArchive(
        id: 'archive_${DateTime.now().millisecondsSinceEpoch}',
        schoolYear: anneeArchivee,
        createdAt: DateTime.now(),
        fileName: fileName,
        childCount: childCount,
        activityCount: activityCount,
        sizeBytes: taille,
      );
    } catch (e) {
      debugPrint('Archivage de fin d\'annee abandonne, rien n\'a ete efface : $e');
      return null;
    }

    await _db.saveArchive(archive);
    await _db.clearTable('children');
    await _db.clearTable('activities');
    await _db.clearAllSons();

    _children = [];
    _activities = [];
    _sonsProgress = {};
    _classSettings = _classSettings.copyWith(schoolYear: nouvelleAnnee);
    await _db.setSetting('class_settings', _classSettings.toJson());

    // Les photos des eleves et des observations ne sont plus referencees ;
    // celles des ateliers le restent et survivent donc a la purge.
    await purgeOrphanPhotos();
    _notify();
    return archive;
  }

  /// Supprime les photos du disque qui ne sont plus referencees.
  ///
  /// Supprimer une observation ou un atelier laissait jusqu'ici ses fichiers
  /// en place : le stockage ne faisait que croitre.
  Future<int> purgeOrphanPhotos() async {
    try {
      _docsDirPath ??= (await getApplicationDocumentsDirectory()).path;
      final referenced = <String>{
        for (final c in _children)
          if (c.imagePath != null && c.imagePath!.isNotEmpty) c.imagePath!,
        for (final a in _activityTypes) ...a.allPhotoPaths,
        for (final l in _activities) ...l.photoPaths,
        if (_classSettings.logoPath != null && _classSettings.logoPath!.isNotEmpty)
          _classSettings.logoPath!,
      }.map(_normalizeRelPath).toSet();

      var removed = 0;
      for (final subDir in ['profiles', 'workshops', 'activities', 'ateliers', 'settings']) {
        final dir = Directory('$_docsDirPath/$subDir');
        if (!await dir.exists()) continue;
        for (final file in dir.listSync().whereType<File>()) {
          final name = file.path.split(Platform.pathSeparator).last;
          if (referenced.contains('$subDir/$name')) continue;
          await file.delete();
          removed++;
        }
      }
      if (removed > 0) debugPrint('Photos orphelines supprimees : $removed');
      return removed;
    } catch (e) {
      debugPrint('Echec de la purge des photos : $e');
      return 0;
    }
  }

  /// Les chemins ont pu etre enregistres en absolu par d'anciennes versions.
  String _normalizeRelPath(String path) {
    var p = path.replaceAll(r'\', '/');
    final docs = _docsDirPath?.replaceAll(r'\', '/');
    if (docs != null && p.startsWith(docs)) {
      p = p.substring(docs.length);
    }
    return p.startsWith('/') ? p.substring(1) : p;
  }

  // ─── ULTRA-ROBUST PHOTO PICKER & STORAGE ───

  /// Cote le plus long des photos enregistrees, et qualite JPEG.
  ///
  /// Applique a toutes les prises de vue et imports, pour que le stockage ne
  /// depende pas de la provenance de l'image.
  static const int photoMaxSize = 1600;
  static const int photoQuality = 85;

  Future<String?> pickAndSavePhoto({
    required ImageSource source,
    required String subDir,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        // Meme traitement pour l'appareil photo que pour la galerie. Les prises
        // de vue etaient auparavant conservees brutes (2 a 5 Mo chacune) : a
        // 1600 px et qualite 85 on tombe autour de 400 Ko, sans difference
        // visible a l'ecran ni a l'impression A4 (~270 dpi sur 15 cm).
        maxWidth: photoMaxSize.toDouble(),
        maxHeight: photoMaxSize.toDouble(),
        imageQuality: photoQuality,
        requestFullMetadata: false,
      );

      if (image == null) {
        debugPrint('[Photo] User cancelled photo pick from $source');
        return null;
      }

      // CRITICAL FOR IOS CAMERA: Read bytes IMMEDIATELY from XFile buffer
      // before iOS dismissViewController purges temporary /tmp/ files!
      Uint8List bytes;
      try {
        bytes = await image.readAsBytes();
      } catch (readErr) {
        debugPrint('[Photo] readAsBytes failed: $readErr, trying File fallback');
        final cleanSourcePath = image.path.replaceFirst('file://', '');
        final sourceFile = File(cleanSourcePath);
        if (await sourceFile.exists()) {
          bytes = await sourceFile.readAsBytes();
        } else {
          bytes = Uint8List(0);
        }
      }

      if (bytes.isEmpty) {
        debugPrint('[Photo Error] Could not read bytes for picked image');
        return null;
      }

      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }

      final targetDir = Directory('$_docsDirPath/$subDir');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final filename = '${subDir}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${targetDir.path}/$filename';

      // Write bytes directly to permanent Documents storage with flush
      await File(targetPath).writeAsBytes(bytes, flush: true);
      debugPrint('[Photo Success] Wrote ${bytes.length} bytes to permanent path: $targetPath');

      // Evict Flutter Image Cache for this path to guarantee immediate UI refresh
      try {
        await FileImage(File(targetPath)).evict();
        imageCache.clear();
        imageCache.clearLiveImages();
      } catch (cacheErr) {
        debugPrint('[Photo Cache Evict] $cacheErr');
      }

      return '$subDir/$filename';
    } catch (e, stack) {
      debugPrint('[Photo Exception] Failed to pick/save photo: $e\n$stack');
      return null;
    }
  }

  // Saves an XFile (from image_picker) directly to Documents using native byte stream
  Future<String> saveXFileToDocs(XFile xfile, String subDir) async {
    try {
      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }
      final targetDir = Directory('$_docsDirPath/$subDir');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      Uint8List bytes;
      try {
        bytes = await xfile.readAsBytes();
      } catch (_) {
        final cleanPath = xfile.path.replaceFirst('file://', '');
        bytes = await File(cleanPath).readAsBytes();
      }

      if (bytes.isEmpty) {
        final cleanPath = xfile.path.replaceFirst('file://', '');
        final f = File(cleanPath);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      final filename = '${DateTime.now().millisecondsSinceEpoch}_${xfile.hashCode}.jpg';
      final newPath = '${targetDir.path}/$filename';
      await File(newPath).writeAsBytes(bytes, flush: true);
      debugPrint('Successfully saved image to: $newPath (${bytes.length} bytes)');
      return '$subDir/$filename';
    } catch (e) {
      debugPrint('Error saving XFile to docs: $e');
      rethrow;
    }
  }

  Future<String> saveImageToDocs(String originalPath, String subDir) async {
    try {
      final cleanOriginalPath = originalPath.replaceFirst('file://', '');
      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }
      final targetDir = Directory('$_docsDirPath/$subDir');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${cleanOriginalPath.hashCode}.jpg';
      final newPath = '${targetDir.path}/$filename';
      final bytes = await File(cleanOriginalPath).readAsBytes();
      await File(newPath).writeAsBytes(bytes, flush: true);
      return '$subDir/$filename';
    } catch (e) {
      debugPrint('Error saving image to docs: $e');
      rethrow;
    }
  }

  // Returns the absolute file path inside the current app documents container
  String? getAbsolutePath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('/') || relativePath.contains(':/') || relativePath.contains(':\\')) {
      return relativePath;
    }
    if (_docsDirPath == null) return null;
    return '$_docsDirPath/$relativePath';
  }

  // ───────────────── BACKUP EXPORT ─────────────────

  /// Construit l'archive complete : donnees et photos.
  ///
  /// Partagee par l'export manuel et par l'archivage de fin d'annee, pour que
  /// les deux ne puissent pas diverger sur ce qui est reellement sauvegarde.
  Future<List<int>> _buildBackupArchiveBytes() async {
    _docsDirPath ??= (await getApplicationDocumentsDirectory()).path;

    final archive = Archive();

    // 1. JSON data
    final backupData = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'class_settings': _classSettings.toMap(),
      'children': _children.map((c) => c.toMap()).toList(),
      'spaces': _spaces.map((s) => s.toMap()).toList(),
      'activity_types': _activityTypes.map((a) => a.toMap()).toList(),
      'activities': _activities.map((l) => l.toMap()).toList(),
      'evaluation_statuses': _evaluationStatuses.map((s) => s.toMap()).toList(),
      'sections': _sections,
      'sons_progress': _sonsProgressAsMap(),
    };
    final jsonBytes = utf8.encode(json.encode(backupData));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    // 2. Photos
    for (final subDir in ['profiles', 'workshops', 'activities']) {
      final dir = Directory('$_docsDirPath/$subDir');
      if (!await dir.exists()) continue;
      for (final file in dir.listSync().whereType<File>()) {
        final bytes = await file.readAsBytes();
        // Le nom seul, separateur de la plateforme compris : un `split('/')`
        // rendait le chemin complet sous Windows et cassait l'arborescence de
        // l'archive lors des tests.
        final name = file.path.split(RegExp(r'[/\\]')).last;
        archive.addFile(ArchiveFile('$subDir/$name', bytes.length, bytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('Erreur lors de la création du ZIP');
    return zipBytes;
  }

  Future<void> exportFullBackup() async {
    try {
      final zipBytes = await _buildBackupArchiveBytes();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = '${tempDir.path}/petitpas_backup_$timestamp.zip';
      await File(zipPath).writeAsBytes(zipBytes);

      // 4. Share
      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'Sauvegarde PetitPas',
        text: 'Backup complet PetitPas incluant toutes les données et photos.',
      );
    } catch (e) {
      debugPrint('Export error: $e');
      rethrow;
    }
  }

  // ───────────────── BACKUP IMPORT ─────────────────
  Future<String> importFullBackup() async {
    try {
      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return 'cancelled';

      final zipPath = result.files.first.path;
      if (zipPath == null) return 'error';

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find backup.json
      ArchiveFile? jsonFile;
      for (final file in archive) {
        if (file.name == 'backup.json') {
          jsonFile = file;
          break;
        }
      }
      if (jsonFile == null) return 'invalid';

      final jsonStr = utf8.decode(jsonFile.content as Uint8List);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      // Restore JSON data
      _classSettings = ClassSettings.fromMap(data['class_settings']);
      _children = (data['children'] as List).map((c) => Child.fromMap(c)).toList();
      if (data['spaces'] != null) {
        _spaces = (data['spaces'] as List).map((s) => Space.fromMap(s)).toList();
      }
      _activityTypes = (data['activity_types'] as List).map((a) => ActivityType.fromMap(a)).toList();
      _activities = (data['activities'] as List).map((l) => ActivityLog.fromMap(l)).toList();
      _evaluationStatuses = _decodeEvaluationStatuses(json.encode(data['evaluation_statuses'] ?? []));
      if (data['sections'] != null) {
        _sections = List<String>.from(data['sections']);
        _write(_db.setSetting('sections', json.encode(_sections)));
      }
      final sonsData = data['sons_progress'];
      _sonsProgress = sonsData is Map
          ? sonsData.map(
              (childId, sons) => MapEntry(
                childId as String,
                (sons as Map).map(
                  (son, code) => MapEntry(son as String, SonStatut.fromCode(code)),
                ),
              ),
            )
          : {};

      // Restore photo files
      for (final file in archive) {
        if (file.name == 'backup.json') continue;
        if (file.isFile) {
          final targetPath = '$_docsDirPath/${file.name}';
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(file.content as Uint8List);
        }
      }

      await _db.replaceAll(
        classSettings: _classSettings,
        children: _children,
        spaces: _spaces,
        activityTypes: _activityTypes,
        activities: _activities,
        evaluationStatuses: _evaluationStatuses,
        sons: _sonsProgress,
      );
      _notify();
      return 'success';
    } catch (e) {
      debugPrint('Import error: $e');
      return 'error';
    }
  }

  void updateClassSettings(ClassSettings settings) {
    _classSettings = settings;
    _write(_db.setSetting('class_settings', settings.toJson()));
    _notify();
  }

  void addOrUpdateChild(Child child) {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index >= 0) {
      _children[index] = child;
    } else {
      _children.add(child);
    }
    _write(_db.saveChild(child));
    _notify();
  }

  /// Supprime un eleve et renvoie de quoi revenir en arriere.
  ///
  /// Ses observations sont conservees en base et en memoire : seule la fiche
  /// disparait, ce qui rend l'annulation possible sans avoir a tout recreer.
  DeletedChild deleteChild(String id) {
    final child = _children.firstWhere((c) => c.id == id,
        orElse: () => Child(id: id, firstname: '', colorHex: '#718096', avatarText: '?'));
    final sons = Map<String, SonStatut>.from(_sonsProgress[id] ?? const {});

    _children.removeWhere((c) => c.id == id);
    _sonsProgress.remove(id);
    _write(_db.deleteChildCascade(id));
    _notify();
    return DeletedChild(child: child, sons: sons);
  }

  /// Retablit un eleve supprime, avec son suivi des sons.
  void restoreChild(DeletedChild deleted) {
    _children.add(deleted.child);
    if (deleted.sons.isNotEmpty) {
      _sonsProgress[deleted.child.id] = Map<String, SonStatut>.from(deleted.sons);
    }
    _write(_db.saveChild(deleted.child));
    deleted.sons.forEach((son, statut) {
      _write(_db.setSon(deleted.child.id, son, statut));
    });
    _notify();
  }

  // ─── SPACES CRUD ───
  void addOrUpdateSpace(Space space) {
    final index = _spaces.indexWhere((s) => s.id == space.id);
    if (index >= 0) {
      _spaces[index] = space;
    } else {
      _spaces.add(space);
    }
    _write(_db.saveSpace(space));
    _notify();
  }

  void deleteSpace(String id) {
    _spaces.removeWhere((s) => s.id == id);
    // Also remove ateliers in this space
    final orphanIds = _activityTypes.where((a) => a.spaceId == id).map((a) => a.id).toList();
    _activityTypes.removeWhere((a) => a.spaceId == id);
    _write(_db.deleteSpace(id));
    for (final atelierId in orphanIds) {
      _write(_db.deleteActivityType(atelierId));
    }
    _notify();
  }

  void saveActivityType(ActivityType actType) {
    final index = _activityTypes.indexWhere((a) => a.id == actType.id);
    if (index >= 0) {
      _activityTypes[index] = actType;
    } else {
      _activityTypes.add(actType);
    }
    _write(_db.saveActivityType(actType));
    _notify();
  }

  void addOrUpdateActivityType(ActivityType actType) => saveActivityType(actType);

  void deleteActivityType(String id) {
    _activityTypes.removeWhere((a) => a.id == id);
    _write(_db.deleteActivityType(id));
    _notify();
  }

  void logActivity(ActivityLog activity) {
    _activities.insert(0, activity);
    _write(_db.saveActivity(activity));
    _notify();
  }

  void updateActivityLog(ActivityLog updatedActivity) {
    final index = _activities.indexWhere((a) => a.id == updatedActivity.id);
    if (index >= 0) {
      _activities[index] = updatedActivity;
      _write(_db.saveActivity(updatedActivity));
      _notify();
    }
  }

  /// Supprime une observation et renvoie l'enregistrement retire, pour
  /// permettre une annulation immediate.
  ActivityLog? deleteActivityLog(String id) {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index < 0) return null;
    final removed = _activities.removeAt(index);
    _write(_db.deleteActivity(id));
    _notify();
    return removed;
  }

  /// Retablit une observation supprimee.
  void restoreActivityLog(ActivityLog log) {
    _activities.add(log);
    _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _write(_db.saveActivity(log));
    _notify();
  }

  void setEvaluationStatuses(List<EvaluationStatus> statuses) {
    _evaluationStatuses = statuses;
    _persistEvaluationStatuses();
    _notify();
  }

  void _persistEvaluationStatuses() {
    _write(_db.setSetting('evaluation_statuses',
        json.encode(_evaluationStatuses.map((s) => s.toMap()).toList())));
  }

  /// Relit les niveaux d'evaluation, en acceptant l'ancien format.
  ///
  /// Les versions precedentes enregistraient une simple liste de libelles.
  /// On leur fabrique un identifiant stable, en reutilisant ceux des niveaux
  /// par defaut quand le libelle correspond, emojis mis a part.
  static List<EvaluationStatus> _decodeEvaluationStatuses(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! List) return List<EvaluationStatus>.from(EvaluationStatus.defaults);

    final result = <EvaluationStatus>[];
    for (final item in decoded) {
      if (item is Map) {
        result.add(EvaluationStatus.fromMap(Map<String, dynamic>.from(item)));
      } else if (item is String) {
        result.add(EvaluationStatus.fromLegacyLabel(item, result.length));
      }
    }
    return result.isEmpty ? List<EvaluationStatus>.from(EvaluationStatus.defaults) : result;
  }


  /// Rattache les ateliers a l'identifiant de leur domaine Eduscol.
  ///
  /// Le libelle est conserve : il reste la source pour un domaine
  /// personnalise, qui n'a pas d'identifiant.
  Future<void> _migrateDomainIds() async {
    var migrated = 0;
    for (var i = 0; i < _activityTypes.length; i++) {
      final a = _activityTypes[i];
      if (a.domaineId != null || a.domaine.isEmpty) continue;
      final match = EduscolData.domains.where((d) => d.title == a.domaine).firstOrNull;
      if (match == null) continue;
      final updated = a.copyWith(domaineId: match.id);
      _activityTypes[i] = updated;
      await _db.saveActivityType(updated);
      migrated++;
    }
    if (migrated > 0) debugPrint('Migration des domaines : $migrated atelier(s).');
  }

  /// Convertit les observations qui portent encore un libelle en identifiant.
  ///
  /// Un libelle inconnu — niveau renomme ou supprime depuis — donne lieu a la
  /// creation d'un niveau dedie, pour qu'aucune evaluation ne soit perdue.
  Future<void> _migrateStatusLabels() async {
    final pending = _activities
        .where((a) => a.evaluationStatusId == null && (a.legacyStatusLabel?.isNotEmpty ?? false))
        .toList();
    if (pending.isEmpty) return;

    var statusesChanged = false;
    for (var i = 0; i < _activities.length; i++) {
      final log = _activities[i];
      final label = log.legacyStatusLabel;
      if (log.evaluationStatusId != null || label == null || label.isEmpty) continue;

      final normalized = EvaluationStatus.normalizeLabel(label);
      var match = _evaluationStatuses
          .where((s) => EvaluationStatus.normalizeLabel(s.label) == normalized)
          .firstOrNull;

      if (match == null) {
        match = EvaluationStatus.fromLegacyLabel(label, _evaluationStatuses.length);
        _evaluationStatuses.add(match);
        statusesChanged = true;
      }

      final updated = log.copyWith(evaluationStatusId: match.id);
      _activities[i] = updated;
      await _db.saveActivity(updated);
    }

    if (statusesChanged) _persistEvaluationStatuses();
    debugPrint('Migration des niveaux d evaluation : ${pending.length} observation(s).');
  }



  void resetSelectiveData({
    required bool clearChildren,
    required bool clearActivityTypes,
    required bool clearActivities,
    required bool resetSettings,
    bool clearEvaluationStatuses = false,
    bool clearSpaces = false,
    bool clearPhotos = false,
  }) {
    if (clearChildren) {
      _children = [];
      _sonsProgress = {};
    }
    if (clearActivityTypes) {
      _activityTypes = [];
    }
    if (clearActivities) {
      _activities = [];
    }
    if (clearEvaluationStatuses) {
      _evaluationStatuses = List<EvaluationStatus>.from(EvaluationStatus.defaults);
    }
    if (clearSpaces) {
      _spaces = [
        Space(id: 'space_1', name: 'Coin Arts Visuels', colorHex: '#FF7043', iconName: 'palette'),
        Space(id: 'space_2', name: 'Espace Motricité', colorHex: '#4E9F3D', iconName: 'fitness_center'),
        Space(id: 'space_3', name: 'Coin Lecture', colorHex: '#7E57C2', iconName: 'menu_book'),
        Space(id: 'space_4', name: 'Coin Mathématiques', colorHex: '#FFA726', iconName: 'calculate'),
        Space(id: 'space_5', name: 'Coin Écoute & Musique', colorHex: '#42A5F5', iconName: 'music_note'),
        Space(id: 'space_6', name: 'Coin Jeux & Construction', colorHex: '#8D6E63', iconName: 'extension'),
      ];
    }
    if (resetSettings) {
      _classSettings = ClassSettings(
        name: "Classe Nouvelle (RAZ)",
        teacher: "",
        level: "PS",
        schoolYear: "2026-2027",
      );
    }
    if (clearPhotos) {
      _deleteAllPhotos();
    }
    // Remise a zero : un remplacement global est ici le geste correct.
    _write(_db.replaceAll(
      classSettings: _classSettings,
      children: _children,
      spaces: _spaces,
      activityTypes: _activityTypes,
      activities: _activities,
      evaluationStatuses: _evaluationStatuses,
      sons: _sonsProgress,
    ));
    _notify();
  }

  Future<void> _deleteAllPhotos() async {
    try {
      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }
      for (final subDir in ['profiles', 'workshops', 'activities', 'settings']) {
        final dir = Directory('$_docsDirPath/$subDir');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Error deleting photos: $e');
    }
  }
}

/// Instantane d'un eleve supprime, suffisant pour le retablir.
class DeletedChild {
  final Child child;
  final Map<String, SonStatut> sons;

  const DeletedChild({required this.child, required this.sons});
}
