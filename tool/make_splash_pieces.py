"""Decoupe l'empreinte en morceaux « une main = un morceau ».

1. Taches connexes du masque, sans dilatation (paumes, doigts, feuilles).
2. Chaque petite tache (un doigt) rejoint la grande tache (une paume) la
   plus proche de couleur voisine, a moins de [REACH] px.
3. Le reste (feuilles, gouttes) forme des morceaux a part.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, out_dir, dart_out, check = sys.argv[1:5]
foot = Image.open(src)
foot = foot.crop(foot.getbbox())
W, H = foot.size
rgba = np.asarray(foot)
alpha = rgba[..., 3].astype(float) / 255
rgb = rgba[..., :3].astype(float)

BIG = 1400      # aire (px) a partir de laquelle une tache est une paume
REACH = 34      # distance max doigt -> paume (px)

labels, n = ndimage.label(alpha > 0.5)
ids = list(range(1, n + 1))
area = ndimage.sum(np.ones_like(alpha), labels, ids)
color = {i: rgb[labels == i].mean(0) for i in ids}
big = [i for i, a in zip(ids, area) if a >= BIG]
small = [i for i, a in zip(ids, area) if 30 <= a < BIG]

owner = {i: i for i in ids}
dist_to = {b: ndimage.distance_transform_edt(labels != b) for b in big}
for s in small:
    m = labels == s
    best, score = None, 1e9
    for b in big:
        d = dist_to[b][m].min()
        if d > REACH:
            continue
        cd = np.linalg.norm(color[s] - color[b])
        sc = d + 0.35 * cd
        if cd < 110 and sc < score:
            best, score = b, sc
    if best is not None:
        owner[s] = best

groups = {}
for i, a in zip(ids, area):
    if a < 30:
        continue
    groups.setdefault(owner[i], []).append(i)

pieces = []
for root, members in groups.items():
    region = np.isin(labels, members)
    # Halo anticrenele : le bord adouci (alpha faible) autour du morceau.
    region = ndimage.binary_dilation(region, iterations=2) & (alpha > 0.02)
    ys, xs = np.nonzero(region)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = rgba[y0:y1, x0:x1].copy()
    crop[..., 3] = np.where(region[y0:y1, x0:x1], crop[..., 3], 0)
    pieces.append((x0, y0, x1 - x0, y1 - y0, crop))

# Du talon (bas) vers les orteils (haut).
pieces.sort(key=lambda p: -(p[1] + p[3] / 2))
with open(dart_out, 'w', encoding='utf-8', newline='\n') as f:
    f.write("// GENERE par le decoupage de l'empreinte (une main ou une feuille par\n")
    f.write("// morceau) pour l'animation d'ouverture : ne pas modifier a la main.\n")
    f.write("//\n// Positions en pixels dans l'empreinte entiere, du talon vers les orteils.\n\n")
    f.write(f'const double kSplashFootW = {W};\nconst double kSplashFootH = {H};\n\n')
    f.write('const List<(String, double, double, double, double)> kSplashPieces = [\n')
    for k, (x, y, w, h, crop) in enumerate(pieces):
        name = f'p{k:02d}.png'
        Image.fromarray(crop, 'RGBA').save(f'{out_dir}/{name}', optimize=True)
        f.write(f"  ('assets/images/splash/{name}', {x}, {y}, {w}, {h}),\n")
    f.write('];\n')

rng = np.random.default_rng(5)
vis = np.full((H, W, 3), 255, np.uint8)
for (x, y, w, h, crop) in pieces:
    c = rng.integers(20, 210, 3)
    vis[y:y + h, x:x + w][crop[..., 3] > 60] = c
Image.fromarray(vis).save(check)
print(f'{len(pieces)} morceaux ({len(big)} paumes), empreinte {W}x{H}')
