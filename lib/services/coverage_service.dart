import '../data/eduscol_data.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';

/// Un domaine delaisse pour un eleve.
class DomainGap {
  final Child child;
  final EduscolDomain domain;

  /// Derniere observation dans ce domaine, ou null : jamais.
  final DateTime? last;

  const DomainGap({required this.child, required this.domain, this.last});

  /// Jours depuis la derniere observation (null : jamais).
  int? get days => last == null ? null : DateTime.now().difference(last!).inDays;
}

/// Ce qu'il reste a travailler : domaines sans observation recente par
/// eleve, objectifs du programme qu'aucun atelier ne travaille.
class CoverageService {
  /// L'ancien domaine « Explorer le monde » couvre les deux domaines qui
  /// l'ont remplace : un atelier pas encore reclasse ne declenche pas
  /// d'alerte a tort.
  static const _legacyCovers = {
    'd5_monde': ['d5_temps_espace', 'd6_vivant_matiere'],
  };

  static Iterable<String> _domainsOf(String? domaineId) =>
      domaineId == null ? const [] : (_legacyCovers[domaineId] ?? [domaineId]);

  /// Derniere observation de l'eleve par domaine du programme.
  static Map<String, DateTime> lastByDomain(AppStateProvider provider, String childId) {
    final out = <String, DateTime>{};
    for (final log in provider.activitiesForChild(childId)) {
      final atelier = provider.activityTypeById(log.activityTypeId);
      for (final d in _domainsOf(atelier?.domaineId)) {
        final prev = out[d];
        if (prev == null || log.timestamp.isAfter(prev)) out[d] = log.timestamp;
      }
    }
    return out;
  }

  /// Eleves x domaines sans observation depuis [days] jours (ou jamais),
  /// les plus anciens d'abord. Seuls les domaines ou la classe a au moins un
  /// atelier comptent : pas d'alerte pour un domaine que rien ne travaille
  /// (c'est le role de [uncoveredObjectives]).
  static List<DomainGap> domainGaps(AppStateProvider provider, {int days = 21}) {
    final limit = DateTime.now().subtract(Duration(days: days));
    final worked = {
      for (final a in provider.activityTypes) ..._domainsOf(a.domaineId),
    };
    final domains = EduscolData.domainsForCycle(1).where((d) => worked.contains(d.id)).toList();
    final gaps = <DomainGap>[];
    for (final c in provider.children) {
      final last = lastByDomain(provider, c.id);
      for (final d in domains) {
        final l = last[d.id];
        if (l == null || l.isBefore(limit)) gaps.add(DomainGap(child: c, domain: d, last: l));
      }
    }
    gaps.sort((a, b) {
      if (a.last == null && b.last != null) return -1;
      if (b.last == null && a.last != null) return 1;
      if (a.last != null && b.last != null) {
        final c = a.last!.compareTo(b.last!);
        if (c != 0) return c;
      }
      return a.child.firstname.toLowerCase().compareTo(b.child.firstname.toLowerCase());
    });
    return gaps;
  }

  /// Objectifs du programme (cycle 1) qu'aucun atelier ni aucune etape ne
  /// travaille, pour les niveaux donnes (tous si vide).
  static List<EduscolObjective> uncoveredObjectives(AppStateProvider provider, {Set<String> levels = const {}}) {
    final covered = {for (final a in provider.activityTypes) ...a.objectifs};
    return [
      for (final o in EduscolData.objectives)
        if (!covered.contains(o.text) && (levels.isEmpty || levels.contains(o.level))) o,
    ];
  }

  /// Part des objectifs travailles par au moins un atelier, pour les niveaux
  /// donnes : (travailles, total).
  static (int, int) objectiveCoverage(AppStateProvider provider, {Set<String> levels = const {}}) {
    final all = [
      for (final o in EduscolData.objectives)
        if (levels.isEmpty || levels.contains(o.level)) o,
    ];
    final missing = uncoveredObjectives(provider, levels: levels).length;
    return (all.length - missing, all.length);
  }
}
