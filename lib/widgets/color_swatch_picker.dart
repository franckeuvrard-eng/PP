import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

/// Sélecteur de couleur en pastilles, commun aux formulaires espace et
/// atelier : évite de dupliquer le Wrap de cercles colorés sur chacun.
class ColorSwatchPicker extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onChanged;
  final List<String> palette;

  const ColorSwatchPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
    this.palette = appColorPalette,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: palette.map((hex) {
        final isSelected = hex == selectedHex;
        final color = hexToColor(hex);
        return GestureDetector(
          onTap: () => onChanged(hex),
          // Zone tactile de 44x44 (repere d'accessibilite iOS) autour du
          // disque visuel de 36x36, sans changer son apparence.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow:
                      isSelected ? [BoxShadow(color: color, blurRadius: 8)] : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
