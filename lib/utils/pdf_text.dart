/// Symboles hors Latin-1 traduits en equivalent rendu, plutot que supprimes :
/// un titre « Analyse des sons — état actuel » ne doit pas perdre son tiret,
/// ni « 01/01 → 31/01 » sa fleche.
const Map<int, String> _substitutions = {
  0x2014: '-', // — tiret cadratin
  0x2013: '-', // – tiret demi-cadratin
  0x2012: '-',
  0x2192: '-', // →
  0x2190: '-', // ←
  0x21D2: '=>', // ⇒
  0x2018: "'", // ‘
  0x2019: "'", // ’
  0x201A: "'",
  0x201C: '"', // “
  0x201D: '"', // ”
  0x201E: '"',
  0x2026: '...', // …
  0x2022: '-', // •
  0x00A0: ' ', // espace insecable
  0x202F: ' ', // espace fine insecable
  0x2009: ' ',
  0x0152: 'OE', // Œ
  0x0153: 'oe', // œ, present dans le referentiel Eduscol
  0x0160: 'S',
  0x0161: 's',
  0x0178: 'Y',
  0x017D: 'Z',
  0x017E: 'z',
  0x20AC: 'EUR', // €
  0x2122: '(TM)',
  0x2030: '%%',
};

/// Nettoie un texte destine a un PDF genere avec les polices integrees.
///
/// Les polices Type1 embarquees dans le paquet `pdf` ne gerent **que**
/// Latin-1 : `isRuneSupported` y renvoie `charCode >= 0x00 && charCode <= 0xff`.
/// Tout le reste — emojis, fleches, tirets typographiques, apostrophes
/// courbes, ligatures — s'imprime en rectangle barre.
///
/// On procede donc par liste blanche stricte sur Latin-1, avec traduction
/// prealable des symboles courants. Une liste noire d'emojis ne suffisait pas :
/// les plages Unicode s'etendent a chaque version, et elle laissait passer
/// aussi bien 🟡 que le tiret cadratin.
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
        rune == 0x09;
    if (renderable) buffer.writeCharCode(rune);
  }
  // Le retrait d'un emoji laisse souvent une double espace, ou une espace
  // avant la ponctuation.
  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      // Uniquement la virgule et le point : en typographie française, « ! »,
      // « ? », « : » et « ; » sont précédés d'une espace, qu'il ne faut pas
      // retirer.
      //
      // replaceAllMapped et non replaceAll : ce dernier ne comprend pas les
      // références de groupe et insérait « $1 » littéralement dans le texte.
      .replaceAllMapped(RegExp(r' +([,.])'), (m) => m.group(1)!)
      .trim();
}
