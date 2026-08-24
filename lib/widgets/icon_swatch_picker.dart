import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

/// Aperçu d'icône + bouton pour en choisir une autre (voir
/// [showAppIconPicker]), commun aux formulaires espace et atelier.
class IconSwatchPicker extends StatelessWidget {
  final String? iconName;
  final Color previewColor;
  final IconData fallback;
  final ValueChanged<String?> onChanged;
  final double previewSize;

  const IconSwatchPicker({
    super.key,
    required this.iconName,
    required this.previewColor,
    required this.onChanged,
    this.fallback = Icons.category,
    this.previewSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: previewSize,
          height: previewSize,
          decoration: BoxDecoration(
            color: previewColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconForName(iconName, fallback: fallback),
              color: previewColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showAppIconPicker(context, iconName);
              if (picked != null) {
                onChanged(picked.isEmpty ? null : picked);
              }
            },
            icon: const Icon(Icons.emoji_symbols),
            label: Text(
                iconName == null ? 'Choisir une icône' : 'Icône : $iconName'),
          ),
        ),
      ],
    );
  }
}
