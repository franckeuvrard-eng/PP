import 'package:flutter/material.dart';

/// Convertit un code hexadecimal ('#RRGGBB') stocke sur les modeles
/// (Space, ActivityType, EvaluationStatus, Child...) en [Color] Flutter.
Color hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));
