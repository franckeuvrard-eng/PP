import 'dart:math';
import 'package:flutter/material.dart';

/// Un axe du radar : un libellé et une valeur normalisée entre 0 et 1.
class RadarChartAxis {
  final String label;
  final double value;

  const RadarChartAxis({required this.label, required this.value});
}

/// Diagramme radar (Kiviat) générique : une seule série sur N axes.
///
/// Une seule série n'a pas besoin de légende à part (le titre au-dessus du
/// graphique la nomme) ; chaque axe porte son propre libellé et sa valeur en
/// pourcentage, en étiquetage direct plutôt qu'une légende séparée.
class RadarChart extends StatelessWidget {
  final List<RadarChartAxis> axes;
  final Color color;
  final double size;

  const RadarChart({
    super.key,
    required this.axes,
    this.color = const Color(0xFF4E9F3D),
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final gridColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    return CustomPaint(
      size: Size(size, size),
      painter: _RadarChartPainter(
        axes: axes,
        color: color,
        gridColor: gridColor,
        textColor: textColor,
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<RadarChartAxis> axes;
  final Color color;
  final Color gridColor;
  final Color textColor;

  _RadarChartPainter({
    required this.axes,
    required this.color,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.isEmpty) return;
    final center = size.center(Offset.zero);
    // Rayon reduit pour laisser la place aux libelles autour du cercle.
    final radius = size.shortestSide / 2 * 0.62;
    final n = axes.length;
    final angleStep = (2 * pi) / n;

    Offset vertex(int i, double fraction) {
      final angle = -pi / 2 + i * angleStep;
      return center + Offset(cos(angle), sin(angle)) * radius * fraction;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Anneaux de graduation (25/50/75/100%).
    for (final fraction in const [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = vertex(i, fraction);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axes.
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, 1.0), gridPaint);
    }

    // Polygone de donnees.
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final p = vertex(i, axes[i].value.clamp(0.0, 1.0));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = color.withOpacity(0.25));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(vertex(i, axes[i].value.clamp(0.0, 1.0)), 4, Paint()..color = color);
    }

    // Etiquettes directes : libelle + valeur, une par axe.
    for (var i = 0; i < n; i++) {
      final labelPoint = vertex(i, 1.28);
      final tp = TextPainter(
        text: TextSpan(
          text: '${axes[i].label}\n${(axes[i].value * 100).round()}%',
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      tp.paint(canvas, labelPoint - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.axes != axes ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}
