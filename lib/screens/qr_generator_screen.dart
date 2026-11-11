import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/activity_type.dart';
import '../providers/app_provider.dart';
import '../services/atelier_grouping.dart';
import '../services/qr_sheets_pdf_service.dart';
import '../utils/color_utils.dart';

/// Badges QR des eleves et etiquettes QR des ateliers, rangees par domaine.
/// Les QR des etapes de parcours sont dans l'ecran Parcours.
///
/// Page de la barre laterale sur Mac et iPad ; sur iPhone, ouverte depuis
/// Rapports > QR codes ([standalone] : barre de titre avec retour).
class QrGeneratorScreen extends StatelessWidget {
  const QrGeneratorScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final children = provider.children.toList()
      ..sort((a, b) => a.firstname.toLowerCase().compareTo(b.firstname.toLowerCase()));
    final groups = AtelierGrouping.byDomain(provider.activityTypes.where((a) => !a.inProgression));

    const tabs = TabBar(
      tabs: [
        Tab(icon: Icon(Icons.badge), text: 'Badges élèves'),
        Tab(icon: Icon(Icons.category), text: 'Étiquettes ateliers'),
      ],
    );

    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: standalone
              ? AppBar(title: const Text('Badges QR'), bottom: tabs)
              : const PreferredSize(preferredSize: Size.fromHeight(72), child: tabs),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_badges_qr',
            onPressed: () {
              if (DefaultTabController.of(context).index == 0) {
                QrSheetsPdfService.openBadges(context, provider);
              } else {
                QrSheetsPdfService.openAteliers(context, provider);
              }
            },
            backgroundColor: const Color(0xFFFF7043),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('Exporter PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: TabBarView(
            children: [
              GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  return _QrCard(
                    title: '${child.firstname} ${child.lastname ?? ''}'.trim(),
                    subtitle: child.group ?? '',
                    data: QrSheetsPdfService.childData(child.id),
                  );
                },
              ),
              // Ateliers rangés par domaine : une étiquette par atelier.
              CustomScrollView(
                slivers: [
                  if (groups.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('Aucun atelier.', style: TextStyle(color: kMutedTextColor)),
                      ),
                    ),
                  for (final g in groups) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('${g.key} (${g.value.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        delegate: SliverChildListDelegate([
                          for (final ActivityType a in g.value)
                            _QrCard(
                              title: a.name,
                              subtitle: provider.placeOf(a)?.name ?? '',
                              data: QrSheetsPdfService.atelierData(a.id),
                              color: hexToColor(a.colorHex),
                            ),
                        ]),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.title, required this.subtitle, required this.data, this.color});

  final String title;
  final String subtitle;
  final String data;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: color == null ? BorderSide.none : BorderSide(color: color!.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMutedTextColor)),
            const SizedBox(height: 10),
            // Fond blanc : un QR doit rester lisible en mode sombre.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(4),
              child: QrImageView(data: data, version: QrVersions.auto, size: 100.0),
            ),
          ],
        ),
      ),
    );
  }
}
