import 'dart:math';
import 'package:flutter/material.dart';
import '../services/natal_chart_service.dart';
import '../theme/app_theme.dart';

/// Колесо натальной карты: кольцо знаков, дома с номерами, оси
/// (асцендент слева, MC сверху), планеты и линии аспектов в центре.
/// Если дома не рассчитаны (время неизвестно), рисуются знаки и планеты,
/// а 0° Овна находится слева.
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

  double get _asc => chart.ascendant?.longitude ?? 0;

  Offset _pt(Offset c, double radius, double longitude) {
    final a = NatalChartService.angleFor(longitude, _asc);
    return Offset(c.dx + radius * cos(a), c.dy - radius * sin(a));
  }

  void _text(Canvas canvas, String text, Offset center, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 18;
    final signInner = r * 0.85;
    final houseNumR = r * 0.50;
    final aspectR = r * 0.44;

    final strong = Paint()
      ..color = AppColors.gold.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final normal = Paint()
      ..color = AppColors.gold.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final faint = Paint()
      ..color = AppColors.gold.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(c, r, Paint()..color = AppColors.bgMid.withOpacity(0.6));
    canvas.drawCircle(c, r, normal);
    canvas.drawCircle(c, signInner, faint);
    canvas.drawCircle(c, aspectR, normal);

    // Знаки зодиака.
    for (var i = 0; i < 12; i++) {
      canvas.drawLine(_pt(c, signInner, i * 30.0), _pt(c, r, i * 30.0), faint);
      _text(
        canvas,
        NatalChartService.zodiacGlyphs[i],
        _pt(c, (r + signInner) / 2, i * 30.0 + 15),
        r * 0.09,
        AppColors.textMuted,
      );
    }

    // Дома: границы и номера.
    final cusps = chart.houseCusps;
    if (cusps != null) {
      for (var i = 0; i < 12; i++) {
        canvas.drawLine(_pt(c, aspectR, cusps[i]), _pt(c, signInner, cusps[i]), faint);
        final start = cusps[i];
        final span = (cusps[(i + 1) % 12] - start + 360) % 360;
        _text(
          canvas,
          '${i + 1}',
          _pt(c, houseNumR, start + span / 2),
          r * 0.075,
          AppColors.textMuted,
        );
      }
    }

    // Оси: асцендент / десцендент и MC / IC.
    final asc = chart.ascendant;
    final mc = chart.midheaven;
    if (asc != null) {
      canvas.drawLine(_pt(c, aspectR, asc.longitude), _pt(c, r, asc.longitude), strong);
      canvas.drawLine(
        _pt(c, aspectR, asc.longitude + 180),
        _pt(c, r, asc.longitude + 180),
        strong,
      );
      _text(canvas, 'ASC', _pt(c, r + 11, asc.longitude), 9, AppColors.goldBright);
      _text(canvas, 'DSC', _pt(c, r + 11, asc.longitude + 180), 9, AppColors.textMuted);
    }
    if (mc != null) {
      canvas.drawLine(_pt(c, aspectR, mc.longitude), _pt(c, r, mc.longitude), strong);
      canvas.drawLine(
        _pt(c, aspectR, mc.longitude + 180),
        _pt(c, r, mc.longitude + 180),
        strong,
      );
      _text(canvas, 'MC', _pt(c, r + 11, mc.longitude), 9, AppColors.goldBright);
      _text(canvas, 'IC', _pt(c, r + 11, mc.longitude + 180), 9, AppColors.textMuted);
    }

    // Линии аспектов в центре круга.
    for (final aspect in chart.aspects.take(14)) {
      final harmonious = aspect.type.angle == 120 || aspect.type.angle == 60;
      final tense = aspect.type.angle == 90 || aspect.type.angle == 180;
      final color = harmonious
          ? AppColors.goldBright.withOpacity(0.4)
          : tense
              ? AppColors.indigo.withOpacity(0.7)
              : AppColors.textMuted.withOpacity(0.35);
      canvas.drawLine(
        _pt(c, aspectR, aspect.a.longitude),
        _pt(c, aspectR, aspect.b.longitude),
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Планеты. Если две стоят рядом, вторую сдвигаем ближе к центру.
    final sorted = [...chart.planets]..sort((a, b) => a.longitude.compareTo(b.longitude));
    double? prev;
    var level = 0;
    for (final p in sorted) {
      if (prev != null && (p.longitude - prev) < 9) {
        level = (level + 1) % 3;
      } else {
        level = 0;
      }
      prev = p.longitude;

      final radius = r * 0.77 - level * r * 0.075;
      final pos = _pt(c, radius, p.longitude);
      canvas.drawCircle(pos, 9, Paint()..color = AppColors.bgDark);
      canvas.drawCircle(pos, 9, faint);
      _text(canvas, p.emoji, pos, 13, AppColors.goldBright);
      canvas.drawLine(_pt(c, signInner, p.longitude), _pt(c, signInner - 5, p.longitude), normal);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.chart != chart;
}
