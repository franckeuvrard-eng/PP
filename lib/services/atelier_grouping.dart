import '../data/eduscol_data.dart';
import '../models/activity_type.dart';

/// Rangement des ateliers (hors etapes de parcours) par domaine puis
/// sous-domaine, partage par les etiquettes QR et la saisie manuelle.
///
/// Le sous-domaine n'est pas enregistre sur l'atelier : il se deduit de ses
/// objectifs Eduscol. Un atelier dont les objectifs couvrent deux
/// sous-domaines figure dans les deux.
class AtelierGrouping {
  static const noDomain = 'Sans domaine';
  static const otherSubdomain = 'Autres ateliers';

  static String domainTitleOf(ActivityType a) =>
      EduscolData.domainById(a.domaineId)?.title ??
      (a.domaine.trim().isNotEmpty ? a.domaine.trim() : noDomain);

  /// Sous-domaines couverts par les objectifs de l'atelier, dans l'ordre du
  /// programme.
  static List<String> subdomainTitlesOf(ActivityType a) {
    final ids = <String>{
      for (final o in EduscolData.objectives)
        if (a.objectifs.contains(o.text) && (a.domaineId == null || o.domainId == a.domaineId))
          o.subdomainId,
    };
    return [
      for (final s in EduscolData.subdomains)
        if (ids.contains(s.id)) s.title,
    ];
  }

  /// Domaines dans l'ordre du programme, puis les domaines personnalises
  /// (alphabetique), « Sans domaine » en dernier. Ateliers tries par nom.
  static List<MapEntry<String, List<ActivityType>>> byDomain(Iterable<ActivityType> ateliers) {
    final groups = <String, List<ActivityType>>{};
    for (final a in ateliers) {
      (groups[domainTitleOf(a)] ??= []).add(a);
    }
    for (final list in groups.values) {
      list.sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));
    }
    final order = [for (final d in EduscolData.domains) d.title];
    int rank(String t) {
      if (t == noDomain) return 1 << 20;
      final i = order.indexOf(t);
      return i < 0 ? order.length : i;
    }

    return groups.entries.toList()
      ..sort((x, y) {
        final r = rank(x.key).compareTo(rank(y.key));
        return r != 0 ? r : x.key.toLowerCase().compareTo(y.key.toLowerCase());
      });
  }

  /// Ateliers d'un domaine ranges par sous-domaine (« Autres ateliers » pour
  /// ceux sans objectif du programme).
  static List<MapEntry<String, List<ActivityType>>> bySubdomain(List<ActivityType> ateliers) {
    final groups = <String, List<ActivityType>>{};
    for (final a in ateliers) {
      final subs = subdomainTitlesOf(a);
      for (final s in subs.isEmpty ? const [otherSubdomain] : subs) {
        (groups[s] ??= []).add(a);
      }
    }
    final order = [for (final s in EduscolData.subdomains) s.title];
    int rank(String t) {
      final i = order.indexOf(t);
      return i < 0 ? order.length : i;
    }

    return groups.entries.toList()..sort((x, y) => rank(x.key).compareTo(rank(y.key)));
  }
}
