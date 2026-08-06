import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    Child(id: "child_1", firstname: "Léo", lastname: "Martin", birthdate: "2023-04-12", group: "Groupe Rouge", notes: "Allergie noisettes", colorHex: "#4E9F3D", avatarText: "LM"),
    Child(id: "child_2", firstname: "Emma", lastname: "Petit", birthdate: "2023-07-22", group: "Groupe Bleu", notes: "Doudou lapin pour la sieste", colorHex: "#FF7043", avatarText: "EP"),
    Child(id: "child_3", firstname: "Lucas", lastname: "Bernard", birthdate: "2023-02-18", group: "Groupe Rouge", notes: "", colorHex: "#7E57C2", avatarText: "LB"),
    Child(id: "child_4", firstname: "Chloé", lastname: "Dubois", birthdate: "2023-09-05", group: "Groupe Jaune", notes: "Lunettes de vue", colorHex: "#FFA726", avatarText: "CD"),
  ];

  List<ActivityType> _activityTypes = [
    ActivityType(id: "act_1", name: "Atelier Peinture & Arts", category: "Créatif", iconName: "palette", colorHex: "#FF7043"),
    ActivityType(id: "act_2", name: "Motricité & Parcours", category: "Motricité", iconName: "fitness_center", colorHex: "#4E9F3D"),
    ActivityType(id: "act_3", name: "Coin Lecture & Contes", category: "Apprentissage", iconName: "menu_book", colorHex: "#7E57C2"),
    ActivityType(id: "act_4", name: "Graphisme & Tracés", category: "Apprentissage", iconName: "edit", colorHex: "#FFA726"),
    ActivityType(id: "act_5", name: "Sieste & Temps Calme", category: "Bien-être", iconName: "bed", colorHex: "#42A5F5"),
    ActivityType(id: "act_6", name: "Repas & Goûter", category: "Vie pratique", iconName: "restaurant", colorHex: "#8D6E63"),
  ];

  List<ActivityLog> _activities = [
    ActivityLog(
      id: "log_1",
      childId: "child_1",
      activityTypeId: "act_1",
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      emotion: "Joyeux 😊",
      note: "A mélangé du bleu et du jaune pour créer du vert !",
    ),
    ActivityLog(
      id: "log_2",
      childId: "child_2",
      activityTypeId: "act_2",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      emotion: "Concentré 🎯",
      note: "A franchi la poutre d'équilibre sans aide.",
    ),
  ];

  ClassSettings get classSettings => _classSettings;
  List<Child> get children => List.unmodifiable(_children);
  List<ActivityType> get activityTypes => List.unmodifiable(_activityTypes);
  List<ActivityLog> get activities => List.unmodifiable(_activities);

  void updateClassSettings(ClassSettings settings) {
    _classSettings = settings;
    notifyListeners();
  }

  void addOrUpdateChild(Child child) {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index >= 0) {
      _children[index] = child;
    } else {
      _children.add(child);
    }
    notifyListeners();
  }

  void deleteChild(String id) {
    _children.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void addOrUpdateActivityType(ActivityType actType) {
    final index = _activityTypes.indexWhere((a) => a.id == actType.id);
    if (index >= 0) {
      _activityTypes[index] = actType;
    } else {
      _activityTypes.add(actType);
    }
    notifyListeners();
  }

  void deleteActivityType(String id) {
    _activityTypes.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void logActivity(ActivityLog activity) {
    _activities.insert(0, activity);
    notifyListeners();
  }
}
