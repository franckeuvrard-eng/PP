import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
      note: "A mélangé du bleu et du jaune pour créer du vert !",
      evaluationStatus: "Acquis 🟢",
    ),
    ActivityLog(
      id: "log_2",
      childId: "child_2",
      activityTypeId: "act_2",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
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
      final prefs = await SharedPreferences.getInstance();
      final directory = await getApplicationDocumentsDirectory();
      _docsDirPath = directory.path;

      final settingsJson = prefs.getString('class_settings');
      if (settingsJson != null) {
        _classSettings = ClassSettings.fromJson(settingsJson);
      }

      final childrenJson = prefs.getString('children');
      if (childrenJson != null) {
        final List<dynamic> decoded = json.decode(childrenJson);
        _children = decoded.map((item) => Child.fromMap(item)).toList();
      }

      final typesJson = prefs.getString('activity_types');
      if (typesJson != null) {
        final List<dynamic> decoded = json.decode(typesJson);
        _activityTypes = decoded.map((item) => ActivityType.fromMap(item)).toList();
      }

      final activitiesJson = prefs.getString('activities');
      if (activitiesJson != null) {
        final List<dynamic> decoded = json.decode(activitiesJson);
        _activities = decoded.map((item) => ActivityLog.fromMap(item)).toList();
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

      final themeStr = prefs.getString('theme_mode');
      if (themeStr != null) {
        if (themeStr == 'light') {
          _themeMode = ThemeMode.light;
        } else if (themeStr == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
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
      
      String themeStr = 'system';
      if (_themeMode == ThemeMode.light) themeStr = 'light';
      if (_themeMode == ThemeMode.dark) themeStr = 'dark';
      await prefs.setString('theme_mode', themeStr);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  // ─── ULTRA-ROBUST PHOTO PICKER & STORAGE ───
  Future<String?> pickAndSavePhoto({
    required ImageSource source,
    required String subDir,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: source == ImageSource.camera ? null : 1200,
        maxHeight: source == ImageSource.camera ? null : 1200,
        imageQuality: source == ImageSource.camera ? null : 85,
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
  Future<void> exportFullBackup() async {
    try {
      if (_docsDirPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        _docsDirPath = directory.path;
      }

      final archive = Archive();

      // 1. JSON data
      final backupData = {
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'class_settings': _classSettings.toMap(),
        'children': _children.map((c) => c.toMap()).toList(),
        'activity_types': _activityTypes.map((a) => a.toMap()).toList(),
        'activities': _activities.map((l) => l.toMap()).toList(),
        'evaluation_statuses': _evaluationStatuses,
        'categories': _categories,
      };
      final jsonBytes = utf8.encode(json.encode(backupData));
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

      // 2. Photos
      for (final subDir in ['profiles', 'workshops', 'activities']) {
        final dir = Directory('$_docsDirPath/$subDir');
        if (await dir.exists()) {
          final files = dir.listSync().whereType<File>().toList();
          for (final file in files) {
            final bytes = await file.readAsBytes();
            final entryName = '$subDir/${file.path.split('/').last}';
            archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
          }
        }
      }

      // 3. Write ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) throw Exception('Erreur lors de la création du ZIP');

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
      _activityTypes = (data['activity_types'] as List).map((a) => ActivityType.fromMap(a)).toList();
      _activities = (data['activities'] as List).map((l) => ActivityLog.fromMap(l)).toList();
      _evaluationStatuses = List<String>.from(data['evaluation_statuses'] ?? []);
      _categories = List<String>.from(data['categories'] ?? []);

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

      await _saveToPrefs();
      notifyListeners();
      return 'success';
    } catch (e) {
      debugPrint('Import error: $e');
      return 'error';
    }
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

  void importActivityTypePack(List<ActivityType> newTypes) {
    for (var act in newTypes) {
      final existingIndex = _activityTypes.indexWhere((a) => a.name.toLowerCase().trim() == act.name.toLowerCase().trim());
      if (existingIndex == -1) {
        _activityTypes.add(act);
      }
    }
    _saveToPrefs();
    notifyListeners();
  }

  void saveActivityType(ActivityType actType) {
    final index = _activityTypes.indexWhere((a) => a.id == actType.id);
    if (index >= 0) {
      _activityTypes[index] = actType;
    } else {
      _activityTypes.add(actType);
    }
    _saveToPrefs();
    notifyListeners();
  }

  void addOrUpdateActivityType(ActivityType actType) => saveActivityType(actType);

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

  void updateActivityLog(ActivityLog updatedActivity) {
    final index = _activities.indexWhere((a) => a.id == updatedActivity.id);
    if (index >= 0) {
      _activities[index] = updatedActivity;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void deleteActivityLog(String id) {
    _activities.removeWhere((a) => a.id == id);
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
