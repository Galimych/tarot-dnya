import 'dart:math';
import 'package:flutter/material.dart';
import '../services/natal_chart_service.dart';
import '../theme/app_theme.dart';

Color aspectColor(double angle) {
  final a = angle.round();
  if (a == 60 || a == 120) return const Color(0xFF7FD3A0); // мягкие
  if (a == 90 || a == 180) return const Color(0xFFE88B8B); // напряжённые
  return AppColors.textWarm; // соединение
}

/// Значок аспекта, нарисованный вручную (шрифты Android не всегда содержат
/// астрологические символы аспектов, а нарисованные работают везде).
class AspectSymbol extends StatelessWidget {
  final double angle;
  final double size;
  const AspectSymbol({super.key, required this.angle, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AspectSymbolPainter(angle, aspectColor(angle))),
    );
  }
}

class _AspectSymbolPainter extends CustomPainter {
  final double angle;
  final Color color;
  _AspectSymbolPainter(this.angle, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final a = angle.round();

    if (a == 0) {
      // Соединение: кружок с чёрточкой.
      canvas.drawCircle(c.translate(-r * 0.3, r * 0.3), r * 0.55, paint);
      canvas.drawLine(c.translate(r * 0.1, -r * 0.1), c.translate(r * 0.9, -r * 0.9), paint);
    } else if (a == 60) {
      // Секстиль: шестилучевая звезда.
      for (var k = 0; k < 3; k++) {
        final t = k * pi / 3;
        final d = Offset(cos(t) * r, sin(t) * r);
        canvas.drawLine(c + d, c - d, paint);
      }
    } else if (a == 90) {
      // Квадрат.
      canvas.drawRect(Rect.fromCenter(center: c, width: r * 1.6, height: r * 1.6), paint);
    } else if (a == 120) {
      // Трин: треугольник.
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.95, c.dy + r * 0.7)
        ..lineTo(c.dx - r * 0.95, c.dy + r * 0.7)
        ..close();
      canvas.drawPath(path, paint);
    } else if (a == 180) {
      // Оппозиция: два кружка, соединённые линией.
      canvas.drawCircle(c.translate(-r * 0.75, r * 0.75), r * 0.42, paint);
      canvas.drawCircle(c.translate(r * 0.75, -r * 0.75), r * 0.42, paint);
      canvas.drawLine(c.translate(-r * 0.4, r * 0.4), c.translate(r * 0.4, -r * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AspectSymbolPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.color != color;
}

/// Таблица аспектов (аспектарий): треугольная сетка, где на пересечении двух
/// точек карты стоит значок аспекта между ними, если он есть.
class AspectGrid extends StatelessWidget {
  final NatalChart chart;
  const AspectGrid({super.key, required this.chart});

  String _label(PlanetPosition p) => p.emoji == 'ASC' ? 'AC' : p.emoji;

  @override
  Widget build(BuildContext context) {
    final points = <PlanetPosition>[
      ...chart.planets,
      if (chart.ascendant != null) chart.ascendant!,
      if (chart.midheaven != null) chart.midheaven!,
    ];
    final n = points.length;

    final byPair = <String, ChartAspect>{};
    for (final aspect in chart.aspects) {
      final i = points.indexWhere((p) => p.planetName == aspect.a.planetName);
      final j = points.indexWhere((p) => p.planetName == aspect.b.planetName);
      if (i < 0 || j < 0) continue;
      byPair['${min(i, j)}-${max(i, j)}'] = aspect;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final double cell = (constraints.maxWidth / n).floorToDouble().clamp(20.0, 34.0).toDouble();
      final double fontSize = (cell * 0.45).clamp(9.0, 13.0).toDouble();

      Widget labelCell(String text) => SizedBox(
            width: cell,
            height: cell,
            child: Center(
              child: Text(
                text,
                style: TextStyle(color: AppColors.goldBright, fontSize: fontSize),
              ),
            ),
          );

      Widget aspectCell(int i, int j) {
        final aspect = byPair['$j-$i'];
        return Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold.withOpacity(0.15), width: 0.6),
          ),
          child: aspect == null
              ? null
              : Center(child: AspectSymbol(angle: aspect.type.angle, size: cell * 0.7)),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 1; i < n; i++)
            Row(
              children: [
                labelCell(_label(points[i])),
                for (var j = 0; j < i; j++) aspectCell(i, j),
              ],
            ),
          Row(
            children: [
              SizedBox(width: cell, height: cell),
              for (var j = 0; j < n - 1; j++) labelCell(_label(points[j])),
            ],
          ),
        ],
      );
    });
  }
}
