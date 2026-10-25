import 'package:flutter/material.dart';
import '../data/eduscol_data.dart';

/// Pastille de la tranche d'age donnee par le programme pour un objectif
/// (« Avant 4 ans », « Dès 4 ans », « Dès 5 ans »), avec le niveau usuel.
class AgeChip extends StatelessWidget {
  const AgeChip({super.key, required this.level, this.compact = false});

  final String level;

  /// Niveau seul (PS, MS, GS) : pour les listes serrees.
  final bool compact;

  static Color colorFor(String level) => switch (level) {
        'PS' => const Color(0xFF1E88E5),
        'MS' => const Color(0xFFEF6C00),
        'GS' => const Color(0xFF8E24AA),
        _ => const Color(0xFF718096),
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(level);
    final age = EduscolData.ageLabel(level);
    final label = compact || age == null ? level : '$age · $level';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
