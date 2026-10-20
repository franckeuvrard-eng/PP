import 'package:flutter/material.dart';

import '../data/release_notes.dart';
import '../utils/color_utils.dart';

const _green = Color(0xFF4E9F3D);

/// Nouveautes de la version : affichees une fois apres une mise a jour
/// ([notes] = versions non encore vues), ou toutes depuis l'Aide.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key, this.notes = kReleaseNotes});

  final List<ReleaseNote> notes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveautés')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final note in notes) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text('Version ${note.version} · ${note.date}',
                      style: const TextStyle(fontSize: 13, color: kMutedTextColor)),
                ),
                for (final item in note.items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: _green.withValues(alpha: 0.12),
                            child: Icon(item.icon, color: _green),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(item.text, style: const TextStyle(fontSize: 13, height: 1.35)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('C\'est parti'),
          ),
        ),
      ),
    );
  }
}
