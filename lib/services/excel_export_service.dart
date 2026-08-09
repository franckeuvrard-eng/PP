import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../models/space.dart';
import '../providers/app_provider.dart';

class ExcelExportService {
  /// Export activity logs for a single child to Excel and open Share dialog.
  static Future<void> exportSingleChild({
    required BuildContext context,
    required AppStateProvider provider,
    required Child child,
    required List<ActivityLog> logs,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheetName = 'Activités_${child.firstname}';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Header row
      sheet.appendRow(<xl.CellValue?>[
        xl.TextCellValue('Date'),
        xl.TextCellValue('Élève'),
        xl.TextCellValue('Atelier'),
        xl.TextCellValue('Domaine'),
        xl.TextCellValue('Évaluation'),
        xl.TextCellValue('Observations'),
      ]);

      // Data rows
      for (final log in logs) {
        final actType = provider.activityTypes.firstWhere(
          (a) => a.id == log.activityTypeId,
          orElse: () => ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: ''),
        );
        final space = provider.spaces.firstWhere(
          (s) => s.id == actType.spaceId,
          orElse: () => Space(id: '', name: '', colorHex: ''),
        );
        sheet.appendRow(<xl.CellValue?>[
          xl.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)),
          xl.TextCellValue('${child.firstname} ${child.lastname ?? ""}'),
          xl.TextCellValue(actType.name),
          xl.TextCellValue(space.name),
          xl.TextCellValue(log.evaluationStatus ?? 'Non renseigné'),
          xl.TextCellValue(log.note ?? ''),
        ]);
      }

      final rawBytes = excel.encode();
      if (rawBytes == null) throw Exception('Erreur lors de la génération du fichier Excel.');

      final bytes = Uint8List.fromList(rawBytes);
      final tempDir = await getApplicationDocumentsDirectory();
      final sanitizedName = '${child.firstname}_${child.lastname ?? ""}'.replaceAll(RegExp(r'[^\w\-]'), '_');
      final fileName = 'PetitPas_Activites_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Export Excel PetitPas — ${child.firstname}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Export activity logs for ALL children to Excel and open Share dialog.
  static Future<void> exportFullClass({
    required BuildContext context,
    required AppStateProvider provider,
    required List<Child> children,
    required List<ActivityLog> logs,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheetName = 'Bilan_Classe';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Header row
      sheet.appendRow(<xl.CellValue?>[
        xl.TextCellValue('Date'),
        xl.TextCellValue('Prénom Élève'),
        xl.TextCellValue('Nom Élève'),
        xl.TextCellValue('Groupe'),
        xl.TextCellValue('Atelier'),
        xl.TextCellValue('Domaine'),
        xl.TextCellValue('Évaluation'),
        xl.TextCellValue('Observations'),
      ]);

      final childMap = {for (var c in children) c.id: c};

      for (final log in logs) {
        final child = childMap[log.childId];
        final actType = provider.activityTypes.firstWhere(
          (a) => a.id == log.activityTypeId,
          orElse: () => ActivityType(id: '', name: 'Atelier inconnu', spaceId: '', colorHex: ''),
        );
        final space = provider.spaces.firstWhere(
          (s) => s.id == actType.spaceId,
          orElse: () => Space(id: '', name: '', colorHex: ''),
        );
        sheet.appendRow(<xl.CellValue?>[
          xl.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)),
          xl.TextCellValue(child?.firstname ?? 'Élève inconnu'),
          xl.TextCellValue(child?.lastname ?? ''),
          xl.TextCellValue(child?.group ?? ''),
          xl.TextCellValue(actType.name),
          xl.TextCellValue(space.name),
          xl.TextCellValue(log.evaluationStatus ?? 'Non renseigné'),
          xl.TextCellValue(log.note ?? ''),
        ]);
      }

      final rawBytes = excel.encode();
      if (rawBytes == null) throw Exception('Erreur lors du traitement du fichier Excel.');

      final bytes = Uint8List.fromList(rawBytes);
      final tempDir = await getApplicationDocumentsDirectory();
      final fileName = 'PetitPas_Bilan_Classe_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Bilan Classe PetitPas (Excel)',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation de la classe : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
