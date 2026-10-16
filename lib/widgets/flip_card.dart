import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tarot_card.dart';
import '../theme/app_theme.dart';

/// Карта, которая переворачивается от рубашки к лицевой стороне.
/// [isRevealed] управляет состоянием снаружи, [onTap] вызывается при нажатии
/// на закрытую карту.
class FlipCardWidget extends StatefulWidget {
  final TarotCard card;
  final bool isRevealed;
  final VoidCallback onTap;

  const FlipCardWidget({
    super.key,
    required this.card,
    required this.isRevealed,
    required this.onTap,
  });

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isRevealed) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isRevealed ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * pi;
          final showFront = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _CardFace(card: widget.card, isFront: true),
                  )
                : _CardFace(card: widget.card, isFront: false),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final TarotCard card;
  final bool isFront;

  const _CardFace({required this.card, required this.isFront});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: isFront
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.goldBright, size: 32),
                const SizedBox(height: 12),
                Text(
                  card.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  card.romanNumeral,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1),
                ),
              ],
            )
          : const Icon(Icons.star, color: AppColors.goldBright, size: 36),
    );
  }
}
