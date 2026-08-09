import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Resolution de tramage des pages.
///
/// Par defaut `printing` trame a la densite de l'ecran : agrandie, la page
/// devient floue. 150 dpi donne un zoom net jusqu'a x5 sans alourdir
/// sensiblement le rendu d'une A4.
const double _kPreviewDpi = 150;

/// Ouvre un apercu PDF imprimable, partageable et zoomable.
///
/// Le zoom est natif a `printing` (double tap sur une page, puis pincement),
/// mais rien ne l'indique : un bandeau le signale.
void openPdfViewer(
  BuildContext context, {
  required String title,
  required String fileName,
  required Future<Uint8List> Function(PdfPageFormat format) build,
  String? shareSubject,
  String? shareBody,
  List<String>? shareEmails,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: const Color(0xFF4E9F3D),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF4E9F3D).withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.zoom_in, size: 16, color: Color(0xFF2E7D32)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Double-tapez une page pour l\'agrandir, puis pincez pour zoomer.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: build,
                dpi: _kPreviewDpi,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: fileName,
                shareActionExtraSubject: shareSubject,
                shareActionExtraBody: shareBody,
                shareActionExtraEmails: shareEmails,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
