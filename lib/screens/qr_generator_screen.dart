import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_provider.dart';
import '../models/space.dart';

class QrGeneratorScreen extends StatelessWidget {
  const QrGeneratorScreen({super.key});

  void _showExportDialog(BuildContext context, AppStateProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exporter les QR Codes'),
          content: const Text('Choisissez le type de planche de QR Codes à générer au format PDF pour impression.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.badge),
              label: const Text('Badges Élèves'),
              onPressed: () {
                Navigator.pop(context);
                _exportBadgesPdf(context, provider);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.category),
              label: const Text('Étiquettes Ateliers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E9F3D),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _exportWorkshopsPdf(context, provider);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBadgesPdf(BuildContext context, AppStateProvider provider) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Badges QR Code Élèves - A petit pas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.GridView(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
              children: provider.children.map((child) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '${child.firstname} ${child.lastname ?? ""}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        child.group ?? 'Classe',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 12),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'PETITPAS:CHILD:${child.id}',
                        width: 90,
                        height: 90,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'PETITPAS - SCAN',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500, letterSpacing: 1),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Badges_Eleves_QR.pdf');
  }

  Future<void> _exportWorkshopsPdf(BuildContext context, AppStateProvider provider) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Fiches QR Code Ateliers - A petit pas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.GridView(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
              children: provider.activityTypes.map((act) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        act.name,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        provider.spaces.firstWhere((s) => s.id == act.spaceId, orElse: () => Space(id: '', name: '', colorHex: '')).name,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (act.description != null && act.description!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          act.description!,
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                          textAlign: pw.TextAlign.center,
                          maxLines: 3,
                        ),
                      ],
                      pw.SizedBox(height: 12),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'PETITPAS:ACT:${act.id}',
                        width: 90,
                        height: 90,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'ATELIER - SCAN',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500, letterSpacing: 1),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Etiquettes_Ateliers_QR.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.badge), text: 'Badges Élèves'),
            Tab(icon: Icon(Icons.category), text: 'Etiquettes Ateliers'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showExportDialog(context, provider),
          backgroundColor: const Color(0xFFFF7043),
          icon: const Icon(Icons.download, color: Colors.white),
          label: const Text('Exporter PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: TabBarView(
          children: [
            // Student Badges Sheet
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: provider.children.length,
              itemBuilder: (context, index) {
                final child = provider.children[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${child.firstname} ${child.lastname ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          child.group ?? 'Classe PS',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                        ),
                        const SizedBox(height: 10),
                        QrImageView(
                          data: 'PETITPAS:CHILD:${child.id}',
                          version: QrVersions.auto,
                          size: 110.0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Activity Cards Sheet
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: provider.activityTypes.length,
              itemBuilder: (context, index) {
                final act = provider.activityTypes[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          act.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          provider.spaces.firstWhere((s) => s.id == act.spaceId, orElse: () => Space(id: '', name: '', colorHex: '')).name,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                        ),
                        const SizedBox(height: 10),
                        QrImageView(
                          data: 'PETITPAS:ACT:${act.id}',
                          version: QrVersions.auto,
                          size: 110.0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
