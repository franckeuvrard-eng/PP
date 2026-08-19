import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../models/child.dart';
import '../providers/app_provider.dart';
import '../services/atelier_pdf_service.dart';
import '../services/child_data_export_service.dart';
import '../services/excel_export_service.dart';
import '../services/mandatory_ateliers_pdf_service.dart';
import '../widgets/child_multi_select_dialog.dart';

/// Point d'entree unique pour tous les rapports/exports : jusqu'ici
/// disperses sur plusieurs ecrans (fiche atelier, export RGPD, bilan
/// classe), ce qui les rendait difficiles a retrouver. Les emplacements
/// d'origine restent fonctionnels, cet ecran ne fait que les centraliser
/// et ajoute le nouveau rapport en masse "ateliers obligatoires".
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _pickAtelierAndExport(BuildContext context, AppStateProvider provider) async {
    final atelier = await showModalBottomSheet<ActivityType>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Choisir un atelier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              for (final space in provider.spaces) ...[
                Text(space.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E9F3D))),
                ...provider.activityTypes.where((a) => a.spaceId == space.id).map(
                      (a) => ListTile(
                        dense: true,
                        title: Text(a.name),
                        onTap: () => Navigator.pop(sheetContext, a),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
    if (atelier != null && context.mounted) {
      AtelierPdfService.openPreview(context, provider, atelier);
    }
  }

  Future<void> _pickChildAndExportRgpd(BuildContext context, AppStateProvider provider) async {
    final child = await showDialog<Child>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choisir un élève'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              children: provider.children
                  .map((c) => ListTile(
                        dense: true,
                        title: Text('${c.firstname} ${c.lastname ?? ''}'.trim()),
                        subtitle: c.group == null || c.group!.isEmpty ? null : Text(c.group!),
                        onTap: () => Navigator.pop(dialogContext, c),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
        ],
      ),
    );
    if (child != null && context.mounted) {
      ChildDataExportService.exportChild(context: context, provider: provider, child: child);
    }
  }

  Future<void> _exportMandatoryAteliers(BuildContext context, AppStateProvider provider) async {
    final result = await showChildMultiSelectDialog(context, children: provider.children);
    if (result != null && result.isNotEmpty && context.mounted) {
      MandatoryAteliersPdfService.exportForChildren(context: context, provider: provider, children: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Générez et partagez les documents pour vos élèves et leurs familles.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF4E9F3D),
                child: Icon(Icons.assignment_turned_in, color: Colors.white),
              ),
              title: const Text('Ateliers obligatoires (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                "Liste des ateliers obligatoires et leur statut, pour un ou plusieurs élèves à la fois.",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportMandatoryAteliers(context, provider),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFF7043),
                child: Icon(Icons.picture_as_pdf, color: Colors.white),
              ),
              title: const Text('Fiche atelier (PDF)'),
              subtitle: const Text('Description, objectifs et photos d\'un atelier.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickAtelierAndExport(context, provider),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF42A5F5),
                child: Icon(Icons.privacy_tip, color: Colors.white),
              ),
              title: const Text('Export RGPD élève'),
              subtitle: const Text('Toutes les données personnelles conservées pour un élève.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickChildAndExportRgpd(context, provider),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF7E57C2),
                child: Icon(Icons.table_chart, color: Colors.white),
              ),
              title: const Text('Bilan classe (Excel)'),
              subtitle: const Text('Toutes les observations de la classe, au format tableur.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ExcelExportService.exportFullClass(
                context: context,
                provider: provider,
                children: provider.children,
                logs: provider.activities,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
