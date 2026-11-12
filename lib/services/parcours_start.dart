import '../models/activity_type.dart';
import '../models/child.dart';

/// Etape ou un eleve demarre un parcours : tout n'est pas a faire depuis le
/// debut (arrivee en cours d'annee, groupe plus avance...). Les etapes avant
/// ce depart ne sont ni verrouillees, ni a rattraper, et aucune observation
/// n'est inventee pour elles.
///
/// Source unique pour le verrou ([AtelierEligibilityService]), l'avancement
/// ([ParcoursProgress]), le fil des parcours et le plan de travail.
class ParcoursStart {
  const ParcoursStart._();

  /// Rang, dans [steps] (etapes du parcours dans l'ordre), de la premiere
  /// etape a faire par [child]. 0 s'il commence au debut, ou si l'etape de
  /// depart n'existe plus (supprimee) : mieux vaut tout proposer que cacher
  /// des etapes a tort.
  static int indexFor(Child child, String parcoursId, List<ActivityType> steps) {
    final startId = child.parcoursStarts[parcoursId];
    if (startId == null) return 0;
    final index = steps.indexWhere((s) => s.id == startId);
    return index < 0 ? 0 : index;
  }

  /// Vrai si [child] ne demarre pas ce parcours a la premiere etape.
  static bool startsLate(Child child, String parcoursId, List<ActivityType> steps) =>
      indexFor(child, parcoursId, steps) > 0;
}
