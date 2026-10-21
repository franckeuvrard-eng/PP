import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';

/// Statut d'eligibilite d'un atelier pour un eleve donne.
enum AtelierEligibility {
  /// Propose sans reserve.
  allowed,

  /// Propose, mais l'atelier n'a jamais ete rattache a une section : on ne
  /// peut pas garantir qu'il convient a l'eleve.
  allowedWithWarning,

  /// Retire de la liste : l'atelier est cible sur d'autres sections que
  /// celle de l'eleve.
  blockedSection,

  /// Retire de la liste : l'espace est en mode progression et un atelier
  /// precedent n'est pas encore acquis par l'eleve.
  blockedProgression,
}

class AtelierEligibilityResult {
  final AtelierEligibility status;
  final String message;
  final List<ActivityType> missingPrerequisites;

  const AtelierEligibilityResult({
    required this.status,
    this.message = '',
    this.missingPrerequisites = const [],
  });

  bool get isAllowed =>
      status == AtelierEligibility.allowed || status == AtelierEligibility.allowedWithWarning;
}

/// Determine si un atelier peut etre propose a un eleve donne, en combinant
/// deux regles independantes :
///  - le ciblage par section ([ActivityType.obligatoryGroups]) dit pour qui
///    l'atelier est obligatoire ; il reste accessible (facultatif) a tous ;
///  - si l'atelier est un jalon d'une progression, les jalons precedents
///    (par [ActivityType.position]) doivent deja avoir atteint le seuil de
///    passage de la progression (Progression.minStatusId).
///
/// Reutilise a l'identique par le scan, la saisie manuelle et le suivi par
/// atelier : c'est la seule source de verite pour cette regle.
class AtelierEligibilityService {
  static AtelierEligibilityResult evaluate({
    required AppStateProvider provider,
    required Child child,
    required ActivityType atelier,
  }) {
    final sectionResult = _evaluateSection(child, atelier);
    if (sectionResult.status == AtelierEligibility.blockedSection) {
      return sectionResult;
    }

    final progressionResult = _evaluateProgression(provider, child, atelier);
    if (progressionResult != null) return progressionResult;

    return sectionResult;
  }

  static AtelierEligibilityResult _evaluateSection(Child child, ActivityType atelier) {
    if (!atelier.isObligatory) {
      return const AtelierEligibilityResult(
        status: AtelierEligibility.allowedWithWarning,
        message:
            "Aucune section n'est configurée pour cet atelier — vérifiez qu'il convient à la section de l'élève.",
      );
    }
    if (atelier.obligatoryGroups.isEmpty) {
      // Configure explicitement pour toute la classe.
      return const AtelierEligibilityResult(status: AtelierEligibility.allowed);
    }
    // Obligatoire pour certaines sections seulement : pour les autres il reste
    // accessible, simplement facultatif. Le reserver aux sections ciblees
    // empechait jusqu'ici les autres eleves d'y etre observes.
    return const AtelierEligibilityResult(status: AtelierEligibility.allowed);
  }

  static AtelierEligibilityResult? _evaluateProgression(
    AppStateProvider provider,
    Child child,
    ActivityType atelier,
  ) {
    final progression = provider.progressionById(atelier.progressionId);
    if (progression == null) return null;
    if (atelier.position < 0) return null;

    final priorAteliers = provider
        .ateliersInProgressionOrdered(progression.id)
        .where((a) => a.position >= 0 && a.position < atelier.position)
        .toList();
    if (priorAteliers.isEmpty) return null;

    final missing = <ActivityType>[];
    for (final prior in priorAteliers) {
      if (!meetsThreshold(provider, child.id, prior.id, progression.minStatusId)) {
        missing.add(prior);
      }
    }
    if (missing.isEmpty) return null;

    final names = missing.map((a) => a.name).join(', ');
    return AtelierEligibilityResult(
      status: AtelierEligibility.blockedProgression,
      message: 'Termine d\'abord : $names',
      missingPrerequisites: missing,
    );
  }

  /// Vrai si le dernier statut observe sur cet atelier est au moins aussi
  /// avance que [minStatusId], au sens de l'ordre dans lequel les niveaux
  /// d'evaluation sont configures (voir AppStateProvider.evaluationStatuses,
  /// generalement du moins au plus abouti). Sans seuil configure, retombe sur
  /// le dernier niveau de la liste.
  static bool meetsThreshold(
    AppStateProvider provider,
    String childId,
    String activityTypeId,
    String? minStatusId,
  ) {
    final statuses = provider.evaluationStatuses;
    if (statuses.isEmpty) return false;
    final threshold = minStatusId ?? statuses.last.id;
    final thresholdIndex = statuses.indexWhere((s) => s.id == threshold);
    if (thresholdIndex < 0) return false;

    final logs = provider
        .activitiesForChild(childId)
        .where((l) => l.activityTypeId == activityTypeId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (logs.isEmpty) return false;

    final latestIndex = statuses.indexWhere((s) => s.id == logs.first.evaluationStatusId);
    return latestIndex >= thresholdIndex;
  }

  /// Annote une liste d'ateliers candidats (par defaut tous ceux de la
  /// classe) avec leur eligibilite pour cet eleve.
  static List<MapEntry<ActivityType, AtelierEligibilityResult>> annotate({
    required AppStateProvider provider,
    required Child child,
    List<ActivityType>? candidates,
  }) {
    final list = candidates ?? provider.activityTypes;
    return list
        .map((atelier) => MapEntry(atelier, evaluate(provider: provider, child: child, atelier: atelier)))
        .toList();
  }
}
