import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/child.dart';
import '../models/activity_type.dart';
import '../models/activity.dart';
import '../models/class_settings.dart';

class AppStateProvider extends ChangeNotifier {
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

  List<ActivityType> _activityTypes = [
    ActivityType(id: "act_1", name: "Peinture & Arts", category: "Créatif", iconName: "palette", colorHex: "#FF7043", description: "Atelier peinture, dessin libre ou dirigé, collages."),
    ActivityType(id: "act_2", name: "Motricité & Parcours", category: "Motricité", iconName: "fitness_center", colorHex: "#4E9F3D", description: "Parcours gymnique, lancer, jeux d'opposition, danse."),
    ActivityType(id: "act_3", name: "Lecture & Contes", category: "Apprentissage", iconName: "menu_book", colorHex: "#7E57C2", description: "Écoute de contes, manipulation d'albums, langage oral."),
    ActivityType(id: "act_4", name: "Graphisme & Tracés", category: "Apprentissage", iconName: "edit", colorHex: "#FFA726", description: "Exercices de motricité fine, tracés de lignes, ronds."),
    ActivityType(id: "act_5", name: "Temps Calme", category: "Bien-être", iconName: "bed", colorHex: "#42A5F5", description: "Sieste pour les PS, relaxation, écoute musicale douce."),
    ActivityType(id: "act_6", name: "Repas & Goûter", category: "Vie pratique", iconName: "restaurant", colorHex: "#8D6E63", description: "Autonomie à la cantine, propreté, rangement."),
  ];

  List<ActivityLog> _activities = [
    ActivityLog(
      id: "log_1",
      childId: "child_1",
      activityTypeId: "act_1",
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      emotion: "Joyeux 😊",
      note: "A mélangé du bleu et du jaune pour créer du vert !",
      evaluationStatus: "Acquis 🟢",
    ),
    ActivityLog(
      id: "log_2",
      childId: "child_2",
      activityTypeId: "act_2",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      emotion: "Concentré 🎯",
      note: "A franchi la poutre d'équilibre sans aide.",
      evaluationStatus: "En cours 🟡",
    ),
  ];

  List<String> _evaluationStatuses = [
    'Non acquis 🔴',
    'En cours 🟡',
    'Acquis 🟢',
  ];

  List<String> _categories = [
    'Apprentissage',
    'Créatif',
    'Motricité',
    'Bien-être',
    'Vie pratique',
    'Général',
  ];

  String? _docsDirPath;

  AppStateProvider() {
    _loadFromPrefs();
  }

  ClassSettings get classSettings => _classSettings;
  List<Child> get children => List.unmodifiable(_children);
  List<ActivityType> get activityTypes => List.unmodifiable(_activityTypes);
  List<ActivityLog> get activities => List.unmodifiable(_activities);
  List<String> get evaluationStatuses => List.unmodifiable(_evaluationStatuses);
  List<String> get categories => List.unmodifiable(_categories);

  Future<void> _loadFromPrefs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _docsDirPath = directory.path;

      final prefs = await SharedPreferences.getInstance();

      final settingsJson = prefs.getString('class_settings');
      if (settingsJson != null) {
        _classSettings = ClassSettings.fromJson(settingsJson);
      }

      final childrenJson = prefs.getString('children');
      if (childrenJson != null) {
        final List<dynamic> decoded = json.decode(childrenJson);
        _children = decoded.map((c) => Child.fromMap(c)).toList();
      }

      final activityTypesJson = prefs.getString('activity_types');
      if (activityTypesJson != null) {
        final List<dynamic> decoded = json.decode(activityTypesJson);
        _activityTypes = decoded.map((a) => ActivityType.fromMap(a)).toList();
      }

      final activitiesJson = prefs.getString('activities');
      if (activitiesJson != null) {
        final List<dynamic> decoded = json.decode(activitiesJson);
        _activities = decoded.map((l) => ActivityLog.fromMap(l)).toList();
      }

      final evaluationStatusesJson = prefs.getString('evaluation_statuses');
      if (evaluationStatusesJson != null) {
        final List<dynamic> decoded = json.decode(evaluationStatusesJson);
        _evaluationStatuses = List<String>.from(decoded);
      }

      final categoriesJson = prefs.getString('categories');
      if (categoriesJson != null) {
        final List<dynamic> decoded = json.decode(categoriesJson);
        _categories = List<String>.from(decoded);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('class_settings', _classSettings.toJson());
      await prefs.setString('children', json.encode(_children.map((c) => c.toMap()).toList()));
      await prefs.setString('activity_types', json.encode(_activityTypes.map((a) => a.toMap()).toList()));
      await prefs.setString('activities', json.encode(_activities.map((l) => l.toMap()).toList()));
      await prefs.setString('evaluation_statuses', json.encode(_evaluationStatuses));
      await prefs.setString('categories', json.encode(_categories));
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  // Saves an XFile (from image_picker) directly to Documents using native byte stream
  Future<String> saveXFileToDocs(XFile xfile, String subDir) async {
    if (_docsDirPath == null) {
      final directory = await getApplicationDocumentsDirectory();
      _docsDirPath = directory.path;
    }
    final targetDir = Directory('$_docsDirPath/$subDir');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final bytes = await xfile.readAsBytes();
    final rawName = xfile.name.isNotEmpty ? xfile.name : xfile.path.split('/').last;
    final basename = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '');
    final filename = '${DateTime.now().millisecondsSinceEpoch}_${basename.isEmpty ? "photo.jpg" : basename}';
    final newPath = '${targetDir.path}/$filename';
    await File(newPath).writeAsBytes(bytes);
    return '$subDir/$filename';
  }

  Future<String> saveImageToDocs(String originalPath, String subDir) async {
    final cleanOriginalPath = originalPath.replaceFirst('file://', '');
    if (_docsDirPath == null) {
      final directory = await getApplicationDocumentsDirectory();
      _docsDirPath = directory.path;
    }
    final targetDir = Directory('$_docsDirPath/$subDir');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    // Clean originalPath name from weird chars
    final basename = cleanOriginalPath.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '');
    final filename = '${DateTime.now().millisecondsSinceEpoch}_$basename';
    final newPath = '${targetDir.path}/$filename';
    final bytes = await File(cleanOriginalPath).readAsBytes();
    await File(newPath).writeAsBytes(bytes);
    return '$subDir/$filename';
  }

  // Returns the absolute file path inside the current app documents container
  String? getAbsolutePath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    // Check if it's already an absolute path
    if (relativePath.startsWith('/') || relativePath.contains(':/') || relativePath.contains(':\\')) {
      return relativePath;
    }
    if (_docsDirPath == null) return null;
    return '$_docsDirPath/$relativePath';
  }

  void updateClassSettings(ClassSettings settings) {
    _classSettings = settings;
    _saveToPrefs();
    notifyListeners();
  }

  void addOrUpdateChild(Child child) {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index >= 0) {
      _children[index] = child;
    } else {
      _children.add(child);
    }
    _saveToPrefs();
    notifyListeners();
  }

  void deleteChild(String id) {
    _children.removeWhere((c) => c.id == id);
    _saveToPrefs();
    notifyListeners();
  }

  void addOrUpdateActivityType(ActivityType actType) {
    final index = _activityTypes.indexWhere((a) => a.id == actType.id);
    if (index >= 0) {
      _activityTypes[index] = actType;
    } else {
      _activityTypes.add(actType);
    }
    _saveToPrefs();
    notifyListeners();
  }

  void deleteActivityType(String id) {
    _activityTypes.removeWhere((a) => a.id == id);
    _saveToPrefs();
    notifyListeners();
  }

  void logActivity(ActivityLog activity) {
    _activities.insert(0, activity);
    _saveToPrefs();
    notifyListeners();
  }

  void setEvaluationStatuses(List<String> statuses) {
    _evaluationStatuses = statuses;
    _saveToPrefs();
    notifyListeners();
  }

  void setCategories(List<String> categories) {
    _categories = categories;
    _saveToPrefs();
    notifyListeners();
  }

  void resetSelectiveData({
    required bool clearChildren,
    required bool clearActivityTypes,
    required bool clearActivities,
    required bool resetSettings,
  }) {
    if (clearChildren) {
      _children = [];
    }
    if (clearActivityTypes) {
      _activityTypes = [];
    }
    if (clearActivities) {
      _activities = [];
    }
    if (resetSettings) {
      _classSettings = ClassSettings(
        name: "Classe Nouvelle (RAZ)",
        teacher: "",
        level: "PS",
        schoolYear: "2026-2027",
      );
    }
    _saveToPrefs();
    notifyListeners();
  }
}
