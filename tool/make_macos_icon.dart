// Fabrique l'icone macOS a partir de l'icone iOS (assets/images/app_icon.jpg).
//
//   dart run tool/make_macos_icon.dart
//
// iOS arrondit lui-meme les icones ; macOS non : il faut fournir la forme
// « squircle » avec ses marges, selon la grille d'Apple (carre de 824 px
// centre dans 1024, coins de 185 px, ombre douce). Resultat :
// assets/images/app_icon_macos.png, utilise par flutter_launcher_icons_macos.yaml.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const _canvas = 1024;
const _tile = 824;
const _radius = 185.0;
const _origin = (_canvas - _tile) / 2;

/// Distance signee au carre arrondi (negative a l'interieur).
double _sdRoundedRect(double x, double y, {double dy = 0}) {
  final cx = _canvas / 2, cy = _canvas / 2 + dy, h = _tile / 2 - _radius;
  final qx = (x - cx).abs() - h, qy = (y - cy).abs() - h;
  final ox = max(qx, 0.0), oy = max(qy, 0.0);
  return sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0.0) - _radius;
}

void main() {
  final src = img.decodeJpg(File('assets/images/app_icon.jpg').readAsBytesSync())!;
  final tile = img.copyResize(src,
      width: _tile, height: _tile, interpolation: img.Interpolation.cubic);
  final out = img.Image(width: _canvas, height: _canvas, numChannels: 4);

  for (var y = 0; y < _canvas; y++) {
    for (var x = 0; x < _canvas; x++) {
      final px = x + 0.5, py = y + 0.5;
      // Ombre douce sous l'icone (decalee vers le bas, floue sur 24 px).
      final shadowD = _sdRoundedRect(px, py, dy: 10);
      final shadowA = (0.28 * (1 - ((shadowD + 4) / 28).clamp(0.0, 1.0))).clamp(0.0, 0.28);
      // Icone, bord anticrenele sur un pixel.
      final cover = (0.5 - _sdRoundedRect(px, py)).clamp(0.0, 1.0);
      if (cover <= 0 && shadowA <= 0) continue;

      var r = 0.0, g = 0.0, b = 0.0, a = shadowA;
      if (cover > 0) {
        final p = tile.getPixel((px - _origin).floor().clamp(0, _tile - 1),
            (py - _origin).floor().clamp(0, _tile - 1));
        // Icone par-dessus l'ombre (composition « over »).
        final outA = cover + a * (1 - cover);
        r = p.r * cover / outA;
        g = p.g * cover / outA;
        b = p.b * cover / outA;
        a = outA;
      }
      out.setPixelRgba(x, y, r.round(), g.round(), b.round(), (a * 255).round());
    }
  }
  File('assets/images/app_icon_macos.png').writeAsBytesSync(img.encodePng(out));
  stdout.writeln('assets/images/app_icon_macos.png ecrit (${_canvas}x$_canvas).');
}
