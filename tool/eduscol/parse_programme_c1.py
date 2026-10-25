"""Extrait la hierarchie du programme consolide de maternelle (Eduscol).

Domaine (16pt, marge) > sous-domaine (16pt, decale) > theme (12pt) >
tranche d'age (PS/MS/GS) > objectifs d'apprentissage (colonne gauche).
Ecrit un JSON a cote du PDF.
"""
import json, re, sys
import pymupdf

pdf, out = sys.argv[1], sys.argv[2]
doc = pymupdf.open(pdf)

def norm(t):
    t = t.replace('’', "'").replace(' ', ' ').replace(' ', ' ')
    return re.sub(r'\s+', ' ', t).strip()

def level_of(t):
    if 'avant 4 ans' in t: return 'PS'
    if 'partir de 4 ans' in t: return 'MS'
    if 'partir de 5 ans' in t: return 'GS'
    return None

domains = []
cur_dom = cur_sub = cur_theme = None
level = None
skip = False           # sous-partie « Principes »
in_table = False
split_x = 200
current = None         # objectif en cours de lecture

def flush():
    global current
    if current and cur_sub is not None:
        text = norm(current)
        text = text[:-1] if text.endswith('.') else text
        if text:
            cur_theme_obj = cur_sub['themes'][-1] if cur_sub['themes'] else None
            if cur_theme_obj is None:
                cur_theme_obj = {'title': None, 'objectives': []}
                cur_sub['themes'].append(cur_theme_obj)
            cur_theme_obj['objectives'].append({'level': level, 'text': text})
    current = None

for pno in range(5, len(doc)):
    for b in doc[pno].get_text('dict')['blocks']:
        for l in b.get('lines', []):
            t = ''.join(s['text'] for s in l['spans'])
            if not t.strip(): continue
            s = l['spans'][0]
            x0, y0 = l['bbox'][0], l['bbox'][1]
            size, bold = round(s['size'], 1), 'Bold' in s['font']
            if y0 > 790: continue  # numero de page
            nt = norm(t)

            if bold and size >= 15.5:
                flush(); in_table = False; level = None
                if x0 < 42:
                    cur_dom = {'title': nt, 'subdomains': []}
                    domains.append(cur_dom); cur_sub = None; skip = False
                else:
                    if nt == 'Principes':
                        skip = True; cur_sub = None
                    else:
                        skip = False
                        cur_sub = {'title': nt, 'themes': []}
                        cur_dom['subdomains'].append(cur_sub)
                continue
            if skip or cur_dom is None: continue
            if bold and size >= 9.9 and level_of(nt):
                flush(); in_table = False; level = level_of(nt); continue
            if bold and size >= 11.5:
                flush(); in_table = False; level = None
                if cur_sub is None:
                    continue
                cur_sub['themes'].append({'title': nt, 'objectives': []})
                continue
            if bold and nt.startswith("Objectifs d'apprentissage"):
                flush(); in_table = True
                split_x = 120  # colonne gauche : tirets vers x=39, suites vers x=57
                continue
            if bold and nt.startswith('Exemples de r'):
                pass
                continue
            if not in_table: continue
            if x0 < 38:  # paragraphe hors tableau
                flush(); in_table = False; continue
            if x0 >= split_x: continue  # colonne « exemples de reussite »
            stripped = nt.lstrip()
            if stripped in ('-', '−', '–'):
                flush(); current = ''
            elif stripped.startswith('•') and current is not None:
                # sous-liste d'un objectif (« Utiliser : • ... • ... »)
                sep = ' ' if current.rstrip().endswith(':') else ' ; '
                current = current.rstrip().rstrip(';').rstrip() + sep + stripped.lstrip('• ').rstrip(' ;')
            elif re.match(r'^[-−–]\s', stripped):
                flush(); current = re.sub(r'^[-−–]\s*', '', stripped)
            elif current is not None:
                current += ' ' + stripped
    # un objectif peut se poursuivre sur la page suivante : pas de flush ici
flush()

# Nettoyage : themes sans objectif retires (sauf s'il ne reste rien).
for d in domains:
    for sd in d['subdomains']:
        sd['themes'] = [t for t in sd['themes'] if t['objectives']]
    d['subdomains'] = [sd for sd in d['subdomains'] if sd['themes']]

json.dump(domains, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for d in domains:
    print('D', d['title'])
    for sd in d['subdomains']:
        n = sum(len(t['objectives']) for t in sd['themes'])
        print('   S', sd['title'], f'({n})')
        for t in sd['themes']:
            lv = {}
            for o in t['objectives']: lv[o['level']] = lv.get(o['level'], 0) + 1
            print('      T', t['title'], lv)
