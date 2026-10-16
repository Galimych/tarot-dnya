import 'dart:math';
import 'package:flutter/material.dart';
import '../services/natal_chart_service.dart';
import '../theme/app_theme.dart';

/// Круговая диаграмма натальной карты: кольцо знаков зодиака, планеты
/// на своих долготах и тонкие линии главных аспектов внутри круга.
class NatalWheel extends StatelessWidget {
  final NatalChart chart;
  const NatalWheel({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _WheelPainter(chart)),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final NatalChart chart;
  _WheelPainter(this.chart);

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  Offset _point(Offset c, double radius, double longitude) {
    final a = NatalChartService.angleFor(longitude);
    return Offset(c.dx + radius * cos(a), c.dy - radius * sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - 4;
    final signRing = outer * 0.84;
    final inner = outer * 0.68;

    final line = Paint()
      ..color = AppColors.gold.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faint = Paint()
      ..color = AppColors.gold.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Фон колеса.
    canvas.drawCircle(
      c,
      outer,
      Paint()..color = AppColors.bgMid.withOpacity(0.6),
    );
    canvas.drawCircle(c, outer, line);
    canvas.drawCircle(c, signRing, faint);
    canvas.drawCircle(c, inner, line);

    // Деления между знаками и значки знаков.
    for (var i = 0; i < 12; i++) {
      canvas.drawLine(_point(c, inner, i * 30.0), _point(c, outer, i * 30.0), faint);
      _drawText(
        canvas,
        NatalChartService.zodiacGlyphs[i],
        _point(c, (outer + signRing) / 2 - 2, i * 30.0 + 15),
        outer * 0.085,
        AppColors.textMuted,
      );
    }

    // Линии аспектов — только для самых заметных.
    for (final aspect in chart.aspects.take(12)) {
      final isHarmonious = aspect.type.angle == 120 || aspect.type.angle == 60;
      final isTense = aspect.type.angle == 90 || aspect.type.angle == 180;
      final color = isHarmonious
          ? AppColors.goldBright.withOpacity(0.35)
          : isTense
              ? AppColors.indigo.withOpacity(0.55)
              : AppColors.textMuted.withOpacity(0.3);
      canvas.drawLine(
        _point(c, inner, aspect.a.longitude),
        _point(c, inner, aspect.b.longitude),
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Планеты. Если две стоят очень близко, вторую слегка сдвигаем внутрь,
    // чтобы значки не накладывались друг на друга.
    final sorted = [...chart.planets]..sort((a, b) => a.longitude.compareTo(b.longitude));
    double? prevLongitude;
    var level = 0;
    for (final p in sorted) {
      if (prevLongitude != null && (p.longitude - prevLongitude) < 9) {
        level = (level + 1) % 3;
      } else {
        level = 0;
      }
      prevLongitude = p.longitude;

      final radius = inner - 16 - level * 17;
      final pos = _point(c, radius, p.longitude);
      canvas.drawCircle(pos, 9, Paint()..color = AppColors.bgDark);
      canvas.drawCircle(pos, 9, faint);
      _drawText(canvas, p.emoji, pos, 13, AppColors.goldBright);
      // Короткая отметка на кольце — точное место планеты.
      canvas.drawLine(
        _point(c, inner, p.longitude),
        _point(c, inner - 5, p.longitude),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.chart != chart;
}
