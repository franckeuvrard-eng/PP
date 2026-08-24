import 'package:flutter/material.dart';

/// Convertit un code hexadecimal ('#RRGGBB') stocke sur les modeles
/// (Space, ActivityType, EvaluationStatus, Child...) en [Color] Flutter.
Color hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));

/// Palette de couleurs proposee sur les formulaires espace et atelier.
const List<String> appColorPalette = [
  '#FF7043',
  '#4E9F3D',
  '#7E57C2',
  '#FFA726',
  '#42A5F5',
  '#8D6E63',
  '#E91E63',
  '#00BCD4',
  '#673AB7',
  '#FF5722',
];
