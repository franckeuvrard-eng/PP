import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../models/child.dart';
import '../providers/app_provider.dart';

/// Import d'élèves en masse depuis un fichier Excel : on génère une matrice
/// vierge, l'enseignant la remplit hors de l'application, puis on la
/// réimporte pour créer les fiches élèves d'un coup.
class ChildrenImportService {
  static const _headers = [
    'Prénom *',
    'Nom',
    'Date de naissance (jj/mm/aaaa)',
    'Section / Groupe',
    'Email des parents',
    'Notes',
  ];

  /// Génère le modèle Excel (en-têtes + un exemple + rappel des sections
  /// existantes) et ouvre le partage natif pour que l'enseignant le récupère.
  static Future<void> shareTemplate({
    required BuildContext context,
    required AppStateProvider provider,
  }) async {
    try {
      final excel = xl.Excel.createExcel();
      const sheetName = 'Élèves';
      excel.rename(excel.getDefaultSheet()!, sheetName);
      final sheet = excel[sheetName];

      sheet.appendRow(_headers.map((h) => xl.TextCellValue(h) as xl.CellValue?).toList());
      for (var col = 0; col < _headers.length; col++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .cellStyle = xl.CellStyle(bold: true);
      }

      final exempleSection = provider.sections.isNotEmpty ? provider.sections.first : 'PS';
      sheet.appendRow(<xl.CellValue?>[
        xl.TextCellValue('Léo'),
        xl.TextCellValue('Martin'),
        xl.TextCellValue('12/04/2023'),
        xl.TextCellValue(exempleSection),
        xl.TextCellValue('parents.leo@example.com'),
        xl.TextCellValue('Exemple à remplacer ou supprimer'),
      ]);

      if (provider.sections.isNotEmpty) {
        const sectionsSheetName = 'Sections de la classe';
        final sectionsSheet = excel[sectionsSheetName];
        sectionsSheet.appendRow(<xl.CellValue?>[
          xl.TextCellValue('Sections existantes (recopier l\'orthographe exacte) :'),
        ]);
        for (final section in provider.sections) {
          sectionsSheet.appendRow(<xl.CellValue?>[xl.TextCellValue(section)]);
        }
      }

      final rawBytes = excel.encode();
      if (rawBytes == null) throw Exception('Erreur lors de la génération du modèle.');

      final bytes = Uint8List.fromList(rawBytes);
      final tempDir = await getApplicationDocumentsDirectory();
      final file = File('${tempDir.path}/APetitPas_Modele_Import_Eleves.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Modèle d\'import élèves A petit pas',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du modèle : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Laisse choisir un fichier Excel rempli, crée les élèves correspondants
  /// et affiche un résumé (ajoutés / doublons ignorés / lignes illisibles).
  static Future<void> pickAndImport({
    required BuildContext context,
    required AppStateProvider provider,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final bytes = await File(path).readAsBytes();
      final excel = xl.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) throw Exception('Le fichier ne contient aucune feuille.');

      final sheet = excel.tables[excel.tables.keys.firstWhere(
        (name) => _normalize(name) == _normalize('Élèves'),
        orElse: () => excel.tables.keys.first,
      )]!;
      final rows = sheet.rows;
      if (rows.isEmpty) throw Exception('La feuille est vide.');

      final columns = _mapColumns(rows.first);
      if (!columns.containsKey('firstname')) {
        throw Exception('Colonne "Prénom" introuvable. Utilisez le modèle fourni.');
      }

      final existingNames = provider.children
          .map((c) => _normalizeName(c.firstname, c.lastname))
          .toSet();

      var added = 0;
      final skippedDuplicates = <String>[];
      final warnings = <String>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final firstname = _cellText(row, columns['firstname']).trim();
        if (firstname.isEmpty) continue;

        final lastname = _cellText(row, columns['lastname']).trim();
        final rawBirthdate = columns['birthdate'] != null && columns['birthdate']! < row.length
            ? row[columns['birthdate']!]
            : null;
        final group = _cellText(row, columns['group']).trim();
        final email = _cellText(row, columns['email']).trim();
        final notes = _cellText(row, columns['notes']).trim();

        String? birthdate;
        final birthdateText = _dataToText(rawBirthdate).trim();
        if (birthdateText.isNotEmpty) {
          birthdate = _parseBirthdate(rawBirthdate?.value, birthdateText);
          if (birthdate == null) {
            warnings.add('Ligne ${i + 1} ($firstname) : date de naissance "$birthdateText" illisible, ignorée.');
          }
        }

        final name = _normalizeName(firstname, lastname.isEmpty ? null : lastname);
        if (existingNames.contains(name)) {
          skippedDuplicates.add('$firstname ${lastname.isEmpty ? "" : lastname}'.trim());
          continue;
        }
        existingNames.add(name);

        final child = Child(
          id: 'child_${DateTime.now().millisecondsSinceEpoch}_$i',
          firstname: firstname,
          lastname: lastname.isEmpty ? null : lastname,
          birthdate: birthdate,
          group: group.isEmpty ? null : group,
          notes: notes.isEmpty ? null : notes,
          colorHex: '#4E9F3D',
          avatarText: firstname[0].toUpperCase(),
          email: email.isEmpty ? null : email,
        );
        provider.addOrUpdateChild(child);
        added++;
      }

      if (context.mounted) {
        await _showResultDialog(context, added: added, skippedDuplicates: skippedDuplicates, warnings: warnings);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'import : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> _showResultDialog(
    BuildContext context, {
    required int added,
    required List<String> skippedDuplicates,
    required List<String> warnings,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import terminé'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$added élève${added > 1 ? 's' : ''} ajouté${added > 1 ? 's' : ''}.'),
              if (skippedDuplicates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${skippedDuplicates.length} déjà présent(s), ignoré(s) : ${skippedDuplicates.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Avertissements :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(w, style: const TextStyle(fontSize: 12, color: Colors.orange)),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Associe chaque champ attendu à l'index de sa colonne, en reconnaissant
  /// les en-têtes du modèle même si l'enseignant les a legerement modifiés.
  static Map<String, int> _mapColumns(List<xl.Data?> headerRow) {
    final columns = <String, int>{};
    for (var col = 0; col < headerRow.length; col++) {
      final header = _normalize(_dataToText(headerRow[col]));
      if (header.isEmpty) continue;
      if (header.contains('prenom')) {
        columns['firstname'] = col;
      } else if (header.contains('naissance')) {
        columns['birthdate'] = col;
      } else if (header.contains('section') || header.contains('groupe')) {
        columns['group'] = col;
      } else if (header.contains('mail')) {
        columns['email'] = col;
      } else if (header.contains('note') || header.contains('remarque')) {
        columns['notes'] = col;
      } else if (header.contains('nom')) {
        columns['lastname'] = col;
      }
    }
    return columns;
  }

  static String _cellText(List<xl.Data?> row, int? col) {
    if (col == null || col >= row.length) return '';
    return _dataToText(row[col]);
  }

  static String _dataToText(xl.Data? data) {
    final value = data?.value;
    if (value == null) return '';
    if (value is xl.DateCellValue) {
      final d = value.asDateTimeLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return value.toString().trim();
  }

  /// Tente jj/mm/aaaa puis aaaa-mm-jj ; renvoie le format ISO (aaaa-mm-jj)
  /// utilisé partout ailleurs dans l'application, ou `null` si illisible.
  static String? _parseBirthdate(xl.CellValue? raw, String text) {
    if (raw is xl.DateCellValue) {
      return '${raw.year.toString().padLeft(4, '0')}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
    }
    final frMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (frMatch != null) {
      final day = int.parse(frMatch.group(1)!);
      final month = int.parse(frMatch.group(2)!);
      final year = int.parse(frMatch.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
    if (isoMatch != null) {
      final year = isoMatch.group(1)!;
      final month = isoMatch.group(2)!.padLeft(2, '0');
      final day = isoMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }
    return null;
  }

  static String _normalizeName(String firstname, String? lastname) {
    return _normalize('$firstname ${lastname ?? ""}');
  }

  static String _normalize(String s) {
    var result = s.toLowerCase().trim();
    const accents = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'à': 'a', 'â': 'a',
      'î': 'i', 'ï': 'i',
      'ô': 'o',
      'ù': 'u', 'û': 'u',
      'ç': 'c',
    };
    accents.forEach((accented, plain) => result = result.replaceAll(accented, plain));
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
