"""Genere lib/data/eduscol_data.dart a partir du JSON extrait du programme."""
import json, sys

src, out = sys.argv[1], sys.argv[2]
data = json.load(open(src, encoding='utf-8'))

# Domaines du programme, dans l'ordre du texte officiel. Les identifiants des
# domaines qui existaient deja sont conserves (ateliers enregistres).
META = [
    ('d1_langage', 'l', 'record_voice_over', '#FF7043', ['Mobiliser le langage dans toutes ses dimensions']),
    ('d3_physique', 'p', 'directions_run', '#7E57C2', ["Agir, s'exprimer, comprendre à travers l'activité physique"]),
    ('d4_art', 'a', 'palette', '#E91E63', []),
    ('d2_maths', 'm', 'calculate', '#4E9F3D', ['Acquérir les premiers outils mathématiques']),
    ('d5_temps_espace', 't', 'schedule', '#FFA726', []),
    ('d6_vivant_matiere', 'v', 'public', '#00BCD4', []),
]
assert len(META) == len(data), [d['title'] for d in data]

def q(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"

lines = []
w = lines.append
w("// GENERE a partir du programme officiel : ne pas modifier a la main.")
w("//")
w("// Source : « Programme d'enseignement - École maternelle », Éduscol,")
w("// d'après le BO n° 41 du 31 octobre 2024 et le BO n° 19 du 7 mai 2026")
w("// (eduscol.education.gouv.fr, programme-cycle-1-consolide).")
w("//")
w("// Les identifiants de domaine sont enregistres sur les ateliers : ne jamais")
w("// en renommer ni en retirer. Un domaine qui n'existe plus reste ici avec")
w("// `legacy: true` (il s'affiche encore, mais n'est plus propose). Les")
w("// objectifs, eux, sont enregistres par leur texte : un ancien objectif")
w("// reste lisible sur l'atelier meme s'il a disparu du referentiel.")
w("")
w("class EduscolDomain {")
w("  final String id;")
w("  final String title;")
w("  final String iconName;")
w("  final String colorHex;")
w("")
w("  /// Cycle du programme (1 : maternelle).")
w("  final int cycle;")
w("")
w("  /// Domaine d'un ancien programme : reconnu, plus propose.")
w("  final bool legacy;")
w("")
w("  /// Anciens intitules du meme domaine, pour reconnaitre les ateliers")
w("  /// enregistres avec eux.")
w("  final List<String> legacyTitles;")
w("")
w("  const EduscolDomain({")
w("    required this.id,")
w("    required this.title,")
w("    required this.iconName,")
w("    required this.colorHex,")
w("    this.cycle = 1,")
w("    this.legacy = false,")
w("    this.legacyTitles = const [],")
w("  });")
w("")
w("  bool matchesTitle(String t) => title == t || legacyTitles.contains(t);")
w("}")
w("")
w("/// Sous-domaine d'un domaine (ex. « Découvrir le monde de la matière et des")
w("/// objets »).")
w("class EduscolSubdomain {")
w("  final String id;")
w("  final String domainId;")
w("  final String title;")
w("")
w("  const EduscolSubdomain({required this.id, required this.domainId, required this.title});")
w("}")
w("")
w("class EduscolObjective {")
w("  final String id;")
w("  final String domainId;")
w("  final String subdomainId;")
w("")
w("  /// Theme du sous-domaine (ex. « Découvrir les objets et les matériaux »),")
w("  /// ou null quand le programme n'en donne pas.")
w("  final String? theme;")
w("")
w("  /// 'PS' (à aborder avant 4 ans), 'MS' (à partir de 4 ans), 'GS' (à")
w("  /// partir de 5 ans) : voir [EduscolData.ageLabel].")
w("  final String level;")
w("  final String text;")
w("")
w("  const EduscolObjective({")
w("    required this.id,")
w("    required this.domainId,")
w("    required this.subdomainId,")
w("    this.theme,")
w("    required this.level,")
w("    required this.text,")
w("  });")
w("}")
w("")
w("class EduscolData {")
w("  /// Cycles disponibles. Le cycle 2 viendra s'ajouter ici.")
w("  static const List<int> cycles = [1];")
w("")
w("  /// Niveaux de chaque cycle, dans l'ordre.")
w("  static const Map<int, List<String>> levels = {1: ['PS', 'MS', 'GS']};")
w("")
w("  /// Tranche d'age donnee par le programme pour un niveau.")
w("  static String? ageLabel(String level) => const {")
w("        'PS': 'Avant 4 ans',")
w("        'MS': 'Dès 4 ans',")
w("        'GS': 'Dès 5 ans',")
w("      }[level];")
w("")
w("  static String cycleLabel(int cycle) => const {")
w("        1: 'Cycle 1 · Maternelle',")
w("        2: 'Cycle 2 · CP-CE2',")
w("      }[cycle] ?? 'Cycle $cycle';")
w("")
w("  /// Niveaux ou figure un objectif de ce texte (un meme intitule peut")
w("  /// revenir d'une tranche d'age a l'autre). Vide pour un objectif")
w("  /// personnalise ou d'un ancien programme.")
w("  static List<String> levelsForText(String text) => [")
w("        for (final o in objectives)")
w("          if (o.text == text) o.level,")
w("      ];")
w("")
w("  static EduscolDomain? domainById(String? id) {")
w("    for (final d in domains) {")
w("      if (d.id == id) return d;")
w("    }")
w("    return null;")
w("  }")
w("")
w("  /// Domaine dont l'intitule (actuel ou ancien) est [title].")
w("  static EduscolDomain? domainByTitle(String title) {")
w("    for (final d in domains) {")
w("      if (d.matchesTitle(title)) return d;")
w("    }")
w("    return null;")
w("  }")
w("")
w("  /// Domaines proposes pour un cycle (sans les anciens).")
w("  static List<EduscolDomain> domainsForCycle(int cycle) =>")
w("      [for (final d in domains) if (d.cycle == cycle && !d.legacy) d];")
w("")
w("  static List<EduscolSubdomain> subdomainsOf(String domainId) =>")
w("      [for (final s in subdomains) if (s.domainId == domainId) s];")
w("")
w("  static const List<EduscolDomain> domains = [")
for (did, _, icon, color, legacy_titles), d in zip(META, data):
    w("    EduscolDomain(")
    w(f"      id: {q(did)},")
    w(f"      title: {q(d['title'])},")
    w(f"      iconName: {q(icon)},")
    w(f"      colorHex: {q(color)},")
    if legacy_titles:
        w("      legacyTitles: [" + ', '.join(q(t) for t in legacy_titles) + "],")
    w("    ),")
w("    // Ancien programme (2015-2021) : divise depuis en « Se repérer dans le")
w("    // temps et l'espace » et « Découvrir le monde du vivant, de la matière")
w("    // et des objets ».")
w("    EduscolDomain(")
w("      id: 'd5_monde',")
w("      title: 'Explorer le monde',")
w("      iconName: 'public',")
w("      colorHex: '#26A69A',")
w("      legacy: true,")
w("    ),")
w("  ];")
w("")
subs, objs = [], []
for (did, short, *_), d in zip(META, data):
    for si, sd in enumerate(d['subdomains'], 1):
        sid = f'c1_{short}{si}'
        subs.append((sid, did, sd['title']))
        counters = {}
        for t in sd['themes']:
            for o in t['objectives']:
                counters[o['level']] = counters.get(o['level'], 0) + 1
                oid = f"{sid}_{o['level'].lower()}{counters[o['level']]}"
                objs.append((oid, did, sid, t['title'], o['level'], o['text']))
w("  static const List<EduscolSubdomain> subdomains = [")
for sid, did, title in subs:
    w(f"    EduscolSubdomain(id: {q(sid)}, domainId: {q(did)}, title: {q(title)}),")
w("  ];")
w("")
w("  static const List<EduscolObjective> objectives = [")
last_sub = None
for oid, did, sid, theme, level, text in objs:
    if sid != last_sub:
        title = next(t for s, _, t in subs if s == sid)
        w(f"    // {title}")
        last_sub = sid
    th = f"theme: {q(theme)}, " if theme else ''
    w(f"    EduscolObjective(id: {q(oid)}, domainId: {q(did)}, subdomainId: {q(sid)}, {th}level: {q(level)}, text: {q(text)}),")
w("  ];")
w("}")
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print(len(subs), 'sous-domaines,', len(objs), 'objectifs')
