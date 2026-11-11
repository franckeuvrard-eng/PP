import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

/// Bandeau rouge en haut de toutes les pages quand un enregistrement a
/// echoue : la saisie est visible a l'ecran mais n'est pas sur le disque, et
/// serait perdue a la fermeture de l'application.
class StorageErrorBanner extends StatelessWidget {
  const StorageErrorBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final error = provider.storageError;

    // Arbre identique avec ou sans erreur : sinon le Navigator (child) serait
    // recree a l'apparition du bandeau et l'utilisateur perdrait sa page.
    return Column(
      children: [
        if (error == null) const SizedBox.shrink() else Material(
          color: const Color(0xFFB3261E),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enregistrement impossible',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text(
                          'Vos dernières modifications n’ont pas été sauvegardées sur cet '
                          'appareil. Ne fermez pas l’application : exportez une sauvegarde '
                          'depuis Paramètres, puis redémarrez-la.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        SelectableText('Détail : $error',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Masquer',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: provider.dismissStorageError,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Le bandeau occupe deja la zone de l'encoche.
        Expanded(
          child: MediaQuery.removePadding(
              context: context, removeTop: error != null, child: child),
        ),
      ],
    );
  }
}
