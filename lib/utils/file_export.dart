import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'platform_support.dart';

enum ExportOutcome { saved, shared, cancelled }

/// Remet un fichier genere (Excel, sauvegarde ZIP…) a l'utilisateur.
///
/// Sur ordinateur (Mac, Windows) : fenetre « Enregistrer sous… », plus
/// naturelle qu'un partage, et la feuille de partage macOS echouait faute de
/// point d'ancrage. Sur iPhone/iPad : feuille de partage, ancree sur
/// [origin] (obligatoire sur iPad, cf. [shareOriginOf]).
Future<ExportOutcome> exportFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  String? subject,
  String? text,
  Rect? origin,
}) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  if (isDesktopPlatform) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 ? fileName.substring(dot + 1) : null;
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: data,
      mimeType: mimeType,
      dialogTitle: subject ?? 'Enregistrer',
      type: ext == null ? FileType.any : FileType.custom,
      allowedExtensions: ext == null ? null : [ext],
    );
    return saved == null ? ExportOutcome.cancelled : ExportOutcome.saved;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(data, flush: true);
  final result = await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: mimeType)],
    subject: subject,
    text: text,
    sharePositionOrigin: origin,
  ));
  return result.status == ShareResultStatus.dismissed
      ? ExportOutcome.cancelled
      : ExportOutcome.shared;
}

/// Zone a l'ecran du widget [context] (bouton touche), pour ancrer la
/// feuille de partage sur iPad.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

const kXlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
