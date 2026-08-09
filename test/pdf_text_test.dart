import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/utils/pdf_text.dart';

/// Les polices Type1 intégrées au paquet `pdf` ne rendent que Latin-1
/// (isRuneSupported dans type1_font.dart) ; tout le reste s'imprime en
/// rectangle barré. Ces cas sont ceux qui ont réellement posé problème.
void main() {
  bool renduPossible(String s) => s.runes.every((r) => r <= 0xFF);

  test('les emojis des niveaux d\'évaluation disparaissent', () {
    expect(pdfSafe('Acquis 🟢'), 'Acquis');
    expect(pdfSafe('En cours 🟡'), 'En cours');
    expect(pdfSafe('Non acquis 🔴'), 'Non acquis');
  });

  test('les symboles typographiques sont traduits, pas supprimés', () {
    expect(pdfSafe('Analyse des sons — état actuel'), 'Analyse des sons - état actuel');
    expect(pdfSafe('01/01/2026 → 31/01/2026'), '01/01/2026 - 31/01/2026');
    expect(pdfSafe('L’élève'), "L'élève");
    expect(pdfSafe('cœur'), 'coeur');
    expect(pdfSafe('etc…'), 'etc...');
  });

  test('les accents français sont préservés', () {
    const accents = 'é è ê ë à â ù û ô î ç Ç É À';
    expect(pdfSafe(accents), accents);
  });

  test('aucune sortie ne dépasse Latin-1', () {
    const entrees = [
      'Acquis 🟢',
      '⏳ En attente',
      '✅ Évalués aujourd\'hui',
      '⭐ Obligatoire',
      '📍 Coin lecture',
      'Analyse des sons — état actuel',
      'Langage · conscience phonémique',
      'L’élève a dit « bravo »…',
    ];
    for (final e in entrees) {
      expect(renduPossible(pdfSafe(e)), isTrue, reason: 'échec sur : $e');
    }
  });

  test('le retrait d\'un emoji ne laisse pas de double espace', () {
    expect(pdfSafe('Coin 📚 lecture'), 'Coin lecture');
    expect(pdfSafe('Peinture 🎨, collage'), 'Peinture, collage');
  });

  test('l\'espace française devant la ponctuation double est conservée', () {
    // « ! » « ? » « : » « ; » prennent une espace en français, contrairement
    // a la virgule et au point.
    expect(pdfSafe('Bravo 🎉 !'), 'Bravo !');
    expect(pdfSafe('Objectif : trier'), 'Objectif : trier');
    expect(pdfSafe('Réussi ?'), 'Réussi ?');
  });
}
