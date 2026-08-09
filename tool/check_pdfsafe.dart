// Verification de pdfSafe : aucun caractere sortant ne doit depasser Latin-1.
//
// Les polices Type1 integrees au paquet `pdf` ne rendent que 0x00-0xFF
// (isRuneSupported dans type1_font.dart) ; tout le reste s'imprime en
// rectangle barre. Ce script rejoue les chaines qui ont reellement pose
// probleme dans l'application.
//
// Lancement : dart run tool/check_pdfsafe.dart
//
// Volontairement hors de test/ : l'etape CI supprime ce dossier, que
// `flutter create` regenere avec un widget_test invalide.

import '../lib/utils/pdf_text.dart';

void main() {
  final cases = <String>[
    'Analyse des sons — état actuel',
    'Langage · conscience phonémique & signes graphiques — 3 acquis',
    '01/01/2026 → 31/01/2026',
    'Acquis 🟢',
    'En cours 🟡',
    'Non acquis 🔴',
    '⏳ En attente',
    '✅ Évalués aujourd\'hui',
    '⭐ Obligatoire',
    'cœur, sœur',
    'L’élève a dit « bravo »…',
    'é è ê ë à â ù û ô î ç Ç É À',
  ];

  var ok = true;
  for (final c in cases) {
    final out = pdfSafe(c);
    final bad = out.runes.where((r) => r > 0xFF).toList();
    if (bad.isNotEmpty) ok = false;
    print('${bad.isEmpty ? "OK " : "KO "} ${c.padRight(52)} -> $out');
  }

  if (!ok) {
    print('\nDES CARACTERES NON RENDUS SUBSISTENT');
    throw StateError('pdfSafe laisse passer des caracteres hors Latin-1');
  }
  print('\nTous les textes sont rendus par les polices PDF integrees.');
}
