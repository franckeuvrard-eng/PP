import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/progression.dart';
import '../providers/app_provider.dart';
import 'atelier_eligibility_service.dart';

/// Ou en est un eleve dans un parcours.
class ParcoursPosition {
  /// Rang de la premiere etape pas encore validee ; egal a [total] quand le
  /// parcours est termine.
  final int step;
  final int total;

  /// Etape en cours, ou null si le parcours est termine ou vide.
  final ActivityType? current;

  const ParcoursPosition({required this.step, required this.total, this.current});

  bool get finished => total > 0 && step >= total;

  /// Avancement entre 0 et 1.
  double get ratio => total == 0 ? 0 : step / total;
}

/// Calcul partage par l'ecran Parcours, le rapport de suivi et la frise :
/// une etape est validee quand son dernier statut atteint le seuil de
/// passage du parcours, et l'eleve se trouve sur la premiere non validee.
class ParcoursProgress {
  static ParcoursPosition of({
    required AppStateProvider provider,
    required Progression parcours,
    required List<ActivityType> steps,
    required String childId,
  }) {
    for (var i = 0; i < steps.length; i++) {
      if (!AtelierEligibilityService.meetsThreshold(
          provider, childId, steps[i].id, parcours.minStatusId)) {
        return ParcoursPosition(step: i, total: steps.length, current: steps[i]);
      }
    }
    return ParcoursPosition(step: steps.length, total: steps.length);
  }

  /// Eleves qui suivent le parcours (sections ciblees), tries par prenom.
  static List<Child> childrenFollowing(AppStateProvider provider, Progression parcours) =>
      provider.children.where((c) => parcours.concernsGroup(c.group)).toList()
        ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
}
