import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import '../providers/app_provider.dart';

/// Resultat d'un collage : chemin relatif de la photo enregistree, ou message
/// d'erreur a afficher.
class PastedImage {
  final String? relPath;
  final String? error;
  const PastedImage.ok(this.relPath) : error = null;
  const PastedImage.failed(this.error) : relPath = null;
}

/// Colle une image du presse-papiers dans l'application (photo d'un atelier
/// ou d'une etape), par exemple copiee depuis un site internet.
///
/// Selon le navigateur et le systeme, « copier » depose l'image elle-meme,
/// des fichiers (Finder), un extrait de page HTML contenant l'image, ou
/// seulement son adresse : les quatre cas sont geres, dans cet ordre.
/// L'image est ensuite traitee comme une photo : 1600 px au plus, JPEG.
class ClipboardImageService {
  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.tif', '.tiff'];

  static Future<PastedImage> paste(AppStateProvider provider, String subDir) async {
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) bytes = await _fromFiles();
      if (bytes == null || bytes.isEmpty) bytes = await _fromHtml();
      if (bytes == null || bytes.isEmpty) bytes = await _fromUrlText();
    } catch (e) {
      debugPrint('[Coller] lecture du presse-papiers impossible : $e');
    }
    if (bytes == null || bytes.isEmpty) {
      return const PastedImage.failed(
          "Aucune image dans le presse-papiers. Sur le site, faites « Copier l'image » "
          "(appui long sur iPhone, clic droit sur Mac), puis revenez coller.");
    }

    final jpeg = await compute(normalize, bytes);
    if (jpeg == null) {
      return const PastedImage.failed("Ce format d'image n'est pas reconnu.");
    }
    final relPath = await provider.saveImageBytesToDocs(jpeg, subDir);
    return relPath == null
        ? const PastedImage.failed("L'image n'a pas pu être enregistrée.")
        : PastedImage.ok(relPath);
  }

  static Future<Uint8List?> _fromFiles() async {
    for (final path in await Pasteboard.files()) {
      final lower = path.toLowerCase();
      if (!_imageExtensions.any(lower.endsWith)) continue;
      final f = File(path.replaceFirst('file://', ''));
      if (await f.exists()) return f.readAsBytes();
    }
    return null;
  }

  static Future<Uint8List?> _fromHtml() async {
    final html = await Pasteboard.html;
    if (html == null) return null;
    final src = imageSrcFromHtml(html);
    if (src == null) return null;
    if (src.startsWith('data:image')) {
      final comma = src.indexOf(',');
      if (comma < 0 || !src.substring(0, comma).contains('base64')) return null;
      return Uint8List.fromList(_base64(src.substring(comma + 1)));
    }
    return _download(src);
  }

  static Future<Uint8List?> _fromUrlText() async {
    final text = (await Pasteboard.text)?.trim();
    if (text == null || !RegExp(r'^https?://\S+$').hasMatch(text)) return null;
    return _download(text);
  }

  /// Adresse de la premiere image d'un extrait HTML copie depuis une page.
  @visibleForTesting
  static String? imageSrcFromHtml(String html) {
    final m = RegExp(r'''<img[^>]*?\ssrc\s*=\s*["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
    final src = m?.group(1)?.replaceAll('&amp;', '&').trim();
    if (src == null || src.isEmpty) return null;
    if (src.startsWith('//')) return 'https:$src';
    return src;
  }

  static List<int> _base64(String s) {
    try {
      return const Base64Codec().decode(s.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return const [];
    }
  }

  /// Telecharge une image (10 Mo au plus) ; null si l'adresse n'en est pas une.
  static Future<Uint8List?> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(uri);
      // Certains sites refusent les requetes sans navigateur.
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (A petits pas)');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final type = res.headers.contentType?.primaryType;
      if (res.statusCode != 200 || (type != null && type != 'image')) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(const Duration(seconds: 20))) {
        builder.add(chunk);
        if (builder.length > 10 * 1024 * 1024) return null;
      }
      return builder.takeBytes();
    } catch (e) {
      debugPrint('[Coller] telechargement impossible : $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Image quelconque -> JPEG de 1600 px au plus (comme les photos prises
  /// dans l'application). Execute hors du fil de l'interface.
  @visibleForTesting
  static Uint8List? normalize(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      // Donnees tronquees ou format inconnu : le decodeur peut lever.
      return null;
    }
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    const max = AppStateProvider.photoMaxSize;
    if (image.width > max || image.height > max) {
      image = image.width >= image.height
          ? img.copyResize(image, width: max, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: max, interpolation: img.Interpolation.average);
    }
    // Fond blanc sous la transparence (logos PNG) : le JPEG n'en a pas.
    if (image.hasAlpha) {
      final flat = img.Image(width: image.width, height: image.height);
      img.fill(flat, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, image);
      image = flat;
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: AppStateProvider.photoQuality));
  }
}
