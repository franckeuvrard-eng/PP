import 'dart:io';

import 'package:flutter/material.dart';

/// Vignette d'une photo d'observation ou d'atelier : l'image ENTIERE (sans
/// recadrage) sur un fond neutre, et l'apercu plein ecran au toucher.
///
/// Les vignettes recadraient jusqu'ici les photos (BoxFit.cover) : une photo
/// en hauteur perdait son haut et son bas, sans moyen de la voir en entier.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.path, this.size = 88, this.radius = 10});

  /// Chemin absolu du fichier.
  final String path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPhotoViewer(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            cacheWidth: (size * 3).round(),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

/// Photo en plein ecran, entiere, zoomable (pincement ou molette).
Future<void> showPhotoViewer(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
