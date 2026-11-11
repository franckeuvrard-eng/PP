import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_type.dart';
import '../providers/app_provider.dart';
import '../services/atelier_pdf_service.dart';
import '../services/child_activity_report_service.dart';
import '../services/excel_export_service.dart';
import '../services/mandatory_ateliers_pdf_service.dart';
import '../services/parcours_frise_pdf_service.dart';
import '../services/parcours_report_service.dart';
import '../services/qr_sheets_pdf_service.dart';
import 'qr_generator_screen.dart';
import 'carnet_screen.dart';
import '../models/progression.dart';
import '../utils/color_utils.dart';
import '../utils/pdf_viewer.dart';
import '../widgets/child_multi_select_dialog.dart';
import '../widgets/work_plan_options_dialog.dart';
import '../widgets/child_report_options_dialog.dart';

/// Point d'entree unique pour tous les rapports/exports : jusqu'ici
/// disperses sur plusieurs ecrans (fiche atelier, export RGPD, rapport de
/// classe, import Excel), ce qui les rendait difficiles a retrouver. Les
/// exports par eleve restent aussi accessibles depuis la fiche eleve ;
/// le rapport de classe et l'import Excel, eux, ont demenage ici (et dans
/// Reglages pour l'import) plutot que de rester dupliques.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _pickAtelierAndExport(BuildContext context, AppStateProvider provider) async {
    // Un atelier, une etape, ou un parcours entier (Progression).
    final picked = await showModalBottomSheet<Object>(
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
              const Text('Choisir un atelier ou un parcours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              for (final space in provider.spaces) ...[
                Text(space.name, style: const TextStyle(fontWeight: FontWeight.bold, color: kAccessibleGreenText)),
                ...provider.ateliersInSpace(space.id).map(
                      (a) => ListTile(
                        dense: true,
                        title: Text(a.name),
                        onTap: () => Navigator.pop(sheetContext, a),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
              for (final progression in provider.progressions) ...[
                Text('Parcours · ${progression.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kAccessibleGreenText)),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.timeline, color: kAccessibleGreenText),
                  title: const Text('Fiche du parcours complet', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Toutes les étapes, dans l\'ordre'),
                  onTap: () => Navigator.pop(sheetContext, progression),
                ),
                ...provider.ateliersInProgressionOrdered(progression.id).indexed.map(
                      (e) => ListTile(
                        dense: true,
                        leading: Text('${e.$1 + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        title: Text(e.$2.name),
                        onTap: () => Navigator.pop(sheetContext, e.$2),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
    if (!context.mounted) return;
    if (picked is ActivityType) AtelierPdfService.openPreview(context, provider, picked);
    if (picked is Progression) AtelierPdfService.openParcoursPreview(context, provider, picked);
  }

  Future<void> _pickParcoursAndExportFrise(BuildContext context, AppStateProvider provider) async {
    final parcours = provider.progressions.length == 1
        ? provider.progressions.first
        : await showDialog<Progression>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Choisir un parcours'),
              children: [
                for (final p in provider.progressions)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, p),
                    child: Text(p.name),
                  ),
              ],
            ),
          );
    if (parcours != null && context.mounted) {
      await ParcoursFrisePdfService.export(context: context, provider: provider, parcours: parcours);
    }
  }

  /// Eleves, puis reglages, puis apercu : plan de travail (ateliers) ou
  /// rapport des parcours.
  Future<void> _exportWorkPlan(BuildContext context, AppStateProvider provider, {required bool parcours}) async {
    final children = await showChildMultiSelectDialog(context, children: provider.children);
    if (children == null || children.isEmpty || !context.mounted) return;
    final options = await showWorkPlanOptionsDialog(context, provider: provider, forParcours: parcours);
    if (options == null || !context.mounted) return;
    if (parcours) {
      MandatoryAteliersPdfService.exportParcoursForChildren(
          context: context, provider: provider, children: children, options: options);
    } else {
      MandatoryAteliersPdfService.exportForChildren(
          context: context, provider: provider, children: children, options: options);
    }
  }

  /// Rapport des eleves : un, plusieurs ou toute la classe, puis reglages.
  Future<void> _exportChildReport(BuildContext context, AppStateProvider provider) async {
    final children = await showChildMultiSelectDialog(
      context,
      children: provider.children,
      initialSelection: {for (final c in provider.children) c.id},
    );
    if (children == null || children.isEmpty || !context.mounted) return;
    final options = await showChildReportOptionsDialog(context, provider: provider);
    if (options == null || !context.mounted) return;
    final single = children.length == 1 ? children.first : null;
    openPdfViewer(
      context,
      title: single == null ? 'Rapport des élèves' : 'Rapport - ${single.firstname}',
      fileName: single == null
          ? 'Rapport_eleves.pdf'
          : 'Rapport_${single.firstname}_${single.lastname ?? ""}.pdf'.replaceAll(' ', '_'),
      build: (format) => ChildActivityReportService.generateReportBytes(
          provider: provider, children: children, format: format, options: options),
      shareSubject: single == null
          ? 'Rapport des élèves - ${provider.classSettings.name}'
          : "Rapport d'activités - ${single.firstname}",
      shareBody: single == null
          ? "Veuillez trouver ci-joint le rapport d'activités des élèves."
          : "Veuillez trouver ci-joint le rapport d'activités de ${single.firstname}.",
      shareEmails: single == null || single.parentEmails.isEmpty ? null : single.parentEmails,
    );
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
            style: TextStyle(fontSize: 12, color: kMutedTextColor),
          ),
          const SizedBox(height: 16),
          // Carnet de suivi (obligatoire en maternelle) et synthese de fin de GS.
          for (final (synthese, icon, color, title, subtitle) in const [
            (false, Icons.menu_book, Color(0xFFE8833A), 'Carnet de suivi (PDF)',
                'Par période : les réussites de chaque domaine avec leurs photos, vos commentaires, la signature des parents.'),
            (true, Icons.fact_check, Color(0xFF8E24AA), 'Synthèse de fin de maternelle (PDF)',
                "Le niveau de chaque sous-domaine du programme (suggéré d'après les observations), points forts et besoins."),
          ]) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: provider.children.isEmpty
                    ? null
                    : () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => CarnetScreen(synthese: synthese))),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF4E9F3D),
                child: Icon(Icons.assignment_turned_in, color: Colors.white),
              ),
              title: const Text('Plan de travail (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                "Les ateliers du plan de travail en vignettes, pour un ou plusieurs élèves. "
                "Réglable : statut, statuts à inclure, cases à cocher.",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportWorkPlan(context, provider, parcours: false),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF42A5F5),
                child: Icon(Icons.route, color: Colors.white),
              ),
              title: const Text('Parcours des élèves (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                "Les étapes des parcours en vignettes, pour un ou plusieurs élèves. "
                "Réglable : parcours, statut, statuts à inclure, cases à cocher.",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: provider.progressions.isEmpty ? null : () => _exportWorkPlan(context, provider, parcours: true),
            ),
          ),
          const SizedBox(height: 12),
          // QR codes a imprimer : sur iPhone, c'est leur seule entree.
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFF7043),
                    child: Icon(Icons.qr_code_2, color: Colors.white),
                  ),
                  title: const Text('QR codes', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'Badges des élèves, étiquettes des ateliers (par domaine) et des étapes (par parcours).'),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    tooltip: 'Voir les QR codes',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const QrGeneratorScreen(standalone: true))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.badge, size: 18),
                        label: const Text('Badges élèves'),
                        onPressed: provider.children.isEmpty
                            ? null
                            : () => QrSheetsPdfService.openBadges(context, provider),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.category, size: 18),
                        label: const Text('Étiquettes ateliers'),
                        onPressed: () => QrSheetsPdfService.openAteliers(context, provider),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.timeline, size: 18),
                        label: const Text('Étapes des parcours'),
                        onPressed: provider.progressions.isEmpty
                            ? null
                            : () => QrSheetsPdfService.openParcours(context, provider, provider.progressions),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF42A5F5),
                    child: Icon(Icons.grid_on, color: Colors.white),
                  ),
                  title: const Text('Suivi des parcours', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Tableau croisé élèves × parcours : l\'étape où en est chaque élève.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('PDF'),
                        onPressed: provider.progressions.isEmpty
                            ? null
                            : () => ParcoursReportService.exportPdf(context: context, provider: provider),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('Excel (TCD)'),
                        onPressed: provider.progressions.isEmpty
                            ? null
                            : () => ParcoursReportService.exportExcel(context: context, provider: provider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF5C6BC0),
                child: Icon(Icons.view_carousel, color: Colors.white),
              ),
              title: const Text('Frise d\'un parcours (PDF)'),
              subtitle: const Text('En grand, à afficher en classe pour que les élèves suivent eux-mêmes.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: provider.progressions.isEmpty ? null : () => _pickParcoursAndExportFrise(context, provider),
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
              title: const Text('Fiche atelier ou parcours (PDF)'),
              subtitle: const Text(
                  'Description, objectifs et photos d\'un atelier, ou d\'un parcours avec toutes ses étapes.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickAtelierAndExport(context, provider),
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
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF26A69A),
                child: Icon(Icons.groups, color: Colors.white),
              ),
              title: const Text('Rapport des élèves (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Un élève, plusieurs ou toute la classe. Réglable : période, analyse des sons, référentiels, '
                  'activités par domaine, sous-domaine et parcours.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: provider.children.isEmpty ? null : () => _exportChildReport(context, provider),
            ),
          ),
        ],
      ),
    );
  }
}
