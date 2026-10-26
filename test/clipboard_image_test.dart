import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petitpas/providers/app_provider.dart';
import 'package:petitpas/services/clipboard_image_service.dart';

/// Image collee : conversion en photo de l'application, et adresse de
/// l'image dans un extrait de page copie depuis un navigateur.
void main() {
  test('grande image PNG transparente -> JPEG de 1600 px au plus', () {
    final png = img.Image(width: 3200, height: 1000, numChannels: 4);
    img.fill(png, color: img.ColorRgba8(200, 0, 0, 0)); // transparente
    final out = ClipboardImageService.normalize(Uint8List.fromList(img.encodePng(png)))!;
    final jpg = img.decodeJpg(out)!;
    expect(jpg.width, AppStateProvider.photoMaxSize);
    expect(jpg.height, 500);
    // La transparence devient du blanc.
    final p = jpg.getPixel(10, 10);
    expect(p.r, greaterThan(240));
    expect(p.g, greaterThan(240));
  });

  test('petite image gardee a sa taille ; donnees invalides refusees', () {
    final small = img.Image(width: 300, height: 200);
    final out = ClipboardImageService.normalize(Uint8List.fromList(img.encodePng(small)))!;
    expect(img.decodeJpg(out)!.width, 300);
    expect(ClipboardImageService.normalize(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('adresse de l\'image dans un extrait de page', () {
    expect(
        ClipboardImageService.imageSrcFromHtml(
            '<meta charset="utf-8"><img alt="chat" src="https://ex.fr/chat.jpg?a=1&amp;b=2" width="40">'),
        'https://ex.fr/chat.jpg?a=1&b=2');
    expect(ClipboardImageService.imageSrcFromHtml("<IMG SRC='//cdn.ex.fr/a.png'>"), 'https://cdn.ex.fr/a.png');
    expect(ClipboardImageService.imageSrcFromHtml('<p>Pas d\'image</p>'), isNull);
  });
}
