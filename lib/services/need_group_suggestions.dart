import '../models/child.dart';
import '../providers/app_provider.dart';
import 'atelier_status_resolver.dart';
import 'parcours_progress.dart';

/// Un groupe propose : des eleves au meme endroit d'un apprentissage.
class GroupSuggestion {
  final String title;
  final String detail;
  final String colorHex;
  final List<Child> children;

  const GroupSuggestion({
    required this.title,
    required this.detail,
    required this.colorHex,
    required this.children,
  });
}

/// Groupes de besoin suggeres a partir des observations :
///  - eleves arretes a la meme etape d'un parcours ;
///  - eleves au meme niveau (sauf le plus abouti) sur un atelier ;
///  - eleves qui n'ont jamais fait un atelier de leur plan de travail.
class NeedGroupSuggestions {
  static List<GroupSuggestion> suggest(AppStateProvider provider, {int minSize = 2}) {
    final out = <GroupSuggestion>[];
    int byName(Child a, Child b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase());

    // 1. Parcours : la meme etape en cours.
    for (final p in provider.progressions) {
      final steps = provider.ateliersInProgressionOrdered(p.id);
      if (steps.isEmpty) continue;
      final atStep = <int, List<Child>>{};
      for (final c in ParcoursProgress.childrenFollowing(provider, p)) {
        final pos = ParcoursProgress.of(provider: provider, parcours: p, steps: steps, childId: c.id);
        if (!pos.finished) (atStep[pos.step] ??= []).add(c);
      }
      for (final e in atStep.entries) {
        if (e.value.length < minSize) continue;
        out.add(GroupSuggestion(
          title: '${p.name} · étape ${e.key + 1} : ${steps[e.key].name}',
          detail: '${e.value.length} élèves arrivés à cette étape',
          colorHex: p.colorHex,
          children: e.value..sort(byName),
        ));
      }
    }

    // 2. Ateliers des espaces : meme niveau, hors niveau le plus abouti.
    final statuses = provider.evaluationStatuses;
    final top = statuses.isEmpty ? null : statuses.last.id;
    for (final a in provider.activityTypes.where((a) => !a.inProgression)) {
      final byStatus = <String, List<Child>>{};
      final labels = <String, String>{};
      final neverDone = <Child>[];
      for (final c in provider.children) {
        final snap = AtelierStatusResolver.resolve(provider: provider, childId: c.id, activityTypeId: a.id);
        if (!snap.hasAnyLog) {
          // 3. Plan de travail : jamais fait.
          if (a.isObligatoryForGroup(c.group)) neverDone.add(c);
          continue;
        }
        final id = snap.statusId;
        if (id == null || id == top || id == 'sans_statut') continue;
        (byStatus[id] ??= []).add(c);
        labels[id] = snap.label;
      }
      for (final e in byStatus.entries) {
        if (e.value.length < minSize) continue;
        out.add(GroupSuggestion(
          title: '${a.name} · ${labels[e.key]}',
          detail: '${e.value.length} élèves à ce niveau sur cet atelier',
          colorHex: a.colorHex,
          children: e.value..sort(byName),
        ));
      }
      if (neverDone.length >= minSize) {
        out.add(GroupSuggestion(
          title: '${a.name} · jamais fait',
          detail: '${neverDone.length} élèves ne l\'ont pas encore fait (plan de travail)',
          colorHex: a.colorHex,
          children: neverDone..sort(byName),
        ));
      }
    }
    return out;
  }
}
