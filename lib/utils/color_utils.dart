import 'package:flutter/material.dart';

/// Convertit un code hexadecimal ('#RRGGBB') stocke sur les modeles
/// (Space, ActivityType, EvaluationStatus, Child...) en [Color] Flutter.
Color hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));

/// Gris de texte/legende conforme au contraste WCAG AA sur fond blanc
/// (~4.7:1). A utiliser a la place de `Colors.grey` (~2.7:1) partout ou la
/// couleur colore du texte plutot qu'une icone ou une bordure decorative.
const kMutedTextColor = Color(0xFF616161);

/// Vert de marque conforme au contraste WCAG AA sur fond blanc (~5.1:1),
/// a utiliser quand `Color(0xFF4E9F3D)` (~3.3:1) colore du texte. Le vert de
/// marque d'origine reste approprie en fond de bouton/AppBar/icone, ou le
/// contraste texte n'est pas en cause.
const kAccessibleGreenText = Color(0xFF2E7D32);

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
