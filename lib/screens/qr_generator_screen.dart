import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/app_provider.dart';

class QrGeneratorScreen extends StatelessWidget {
  const QrGeneratorScreen({super.key});

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
                          act.category,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
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
