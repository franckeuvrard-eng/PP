/// Caracteres hors Latin-1 que l'encodage WinAnsi des polices PDF integrees
/// (Helvetica & co) sait tout de meme rendre.
const Set<int> _winAnsiExtras = {
  0x20AC, // €
  0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030,
  0x0160, 0x2039, 0x0152, 0x017D,
  0x2018, 0x2019, 0x201C, 0x201D, // guillemets et apostrophes typographiques
  0x2022, // •
  0x2013, 0x2014, // – —
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x017E, 0x0178,
};

/// Symboles courants remplaces par un equivalent rendu, plutot que supprimes :
/// une plage de dates « 01/01 → 31/01 » deviendrait sinon « 01/01  31/01 ».
const Map<int, String> _substitutions = {
  0x2192: '-', // →
  0x2190: '-', // ←
  0x21D2: '=>', // ⇒
  0x00A0: ' ', // espace insecable
  0x202F: ' ', // espace fine insecable
};

/// Nettoie un texte destine a un PDF genere avec les polices integrees.
///
/// Ces polices ne couvrent que WinAnsi : tout le reste (emojis, fleches,
/// pastilles de couleur, selecteurs de variante) s'imprime en rectangle barre.
/// On procede par liste blanche et non par liste noire d'emojis : les plages
/// Unicode d'emojis s'etendent a chaque version, et c'est precisement ce qui
/// laissait passer 🟡 🟢 ⏳ ⭐ et la fleche des intitules de periode.
String pdfSafe(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final replacement = _substitutions[rune];
    if (replacement != null) {
      buffer.write(replacement);
      continue;
    }
    final renderable = (rune >= 0x20 && rune <= 0x7E) ||
        (rune >= 0xA0 && rune <= 0xFF) ||
        rune == 0x0A ||
        rune == 0x09 ||
        _winAnsiExtras.contains(rune);
    if (renderable) buffer.writeCharCode(rune);
  }
  // Le retrait d'un emoji laisse souvent une double espace ou une espace
  // avant la ponctuation.
  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' +([,.;:!?])'), r'$1')
      .trim();
}
