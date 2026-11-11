import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/eduscol_data.dart';

/// Referentiel Eduscol : programme actuel, et ateliers enregistres avec
/// l'ancien.
void main() {
  test('cycle 1 : les six domaines du programme, sans les anciens', () {
    final domains = EduscolData.domainsForCycle(1);
    expect(domains, hasLength(6));
    expect(domains.any((d) => d.legacy), isFalse);
    expect(domains.map((d) => d.title), contains('Découvrir le monde du vivant, de la matière et des objets'));
  });

  test('domaine > sous-domaine > theme > objectifs', () {
    final sub = EduscolData.subdomains
        .firstWhere((s) => s.title == 'Découvrir le monde de la matière et des objets');
    expect(EduscolData.domainById(sub.domainId)!.title,
        'Découvrir le monde du vivant, de la matière et des objets');
    final objets = EduscolData.objectives
        .where((o) => o.subdomainId == sub.id && o.theme == 'Découvrir les objets et les matériaux')
        .toList();
    expect(objets, isNotEmpty);
    expect(objets.map((o) => o.level).toSet(), {'PS', 'MS', 'GS'});
  });

  test('donnees coherentes : identifiants uniques, rattachements valides', () {
    final ids = EduscolData.objectives.map((o) => o.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    final subs = {for (final s in EduscolData.subdomains) s.id: s};
    for (final o in EduscolData.objectives) {
      expect(subs[o.subdomainId]?.domainId, o.domainId, reason: o.id);
      expect(EduscolData.levels[1], contains(o.level), reason: o.id);
      expect(o.text.trim(), isNotEmpty);
    }
  });

  test('ateliers de l\'ancien programme : domaines toujours reconnus', () {
    // Identifiants enregistres sur les ateliers existants.
    for (final id in ['d1_langage', 'd2_maths', 'd3_physique', 'd4_art', 'd5_monde']) {
      expect(EduscolData.domainById(id), isNotNull, reason: id);
    }
    // Ateliers anterieurs aux identifiants : rattaches par l'ancien intitule.
    expect(EduscolData.domainByTitle('Mobiliser le langage dans toutes ses dimensions')!.id, 'd1_langage');
    expect(EduscolData.domainByTitle('Acquérir les premiers outils mathématiques')!.id, 'd2_maths');
    expect(EduscolData.domainByTitle("Agir, s'exprimer, comprendre à travers l'activité physique")!.id,
        'd3_physique');
    final monde = EduscolData.domainByTitle('Explorer le monde')!;
    expect(monde.legacy, isTrue);
    expect(EduscolData.domainsForCycle(1), isNot(contains(monde)));
  });

  test('tranches d\'age du programme', () {
    expect(EduscolData.ageLabel('PS'), 'Avant 4 ans');
    expect(EduscolData.ageLabel('MS'), 'Dès 4 ans');
    expect(EduscolData.ageLabel('GS'), 'Dès 5 ans');
    final o = EduscolData.objectives.first;
    expect(EduscolData.levelsForText(o.text), contains(o.level));
    // Objectif personnalise ou de l'ancien programme : pas d'age connu.
    expect(EduscolData.levelsForText('Utiliser des ciseaux à bouts ronds'), isEmpty);
  });
}
