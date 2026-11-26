import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// The day's calorie budget as a ring.
///
/// Two arcs are drawn on the same track: a solid one for calories already
/// eaten and a faded one continuing from it for what is still only planned.
/// Seeing both at once is the point — it answers "will today's plan fit?"
/// without arithmetic.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.eaten,
    required this.planned,
    required this.goal,
    this.size = 190,
  });

  final double eaten;
  final double planned;
  final double goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = goal - eaten;
    final isOver = remaining < 0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          eatenFraction: goal <= 0 ? 0 : eaten / goal,
          plannedFraction: goal <= 0 ? 0 : planned / goal,
          trackColor: scheme.surfaceContainerHighest,
          eatenColor: isOver ? FoodLensColors.over : scheme.primary,
          plannedColor: scheme.primary.withValues(alpha: 0.28),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatKcal(remaining.abs()),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isOver ? FoodLensColors.over : scheme.onSurface,
                ),
              ),
              Text(
                isOver ? 'kcal over' : 'kcal igjen',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatKcal(eaten)} / ${formatKcal(goal)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.eatenFraction,
    required this.plannedFraction,
    required this.trackColor,
    required this.eatenColor,
    required this.plannedColor,
  });

  final double eatenFraction;
  final double plannedFraction;
  final Color trackColor;
  final Color eatenColor;
  final Color plannedColor;

  static const double _strokeWidth = 16;
  static const double _startAngle = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = _strokeWidth / 2;
    final arcRect = rect.deflate(inset);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, 2 * math.pi, false, base..color = trackColor);

    // Clamp so an overshoot fills the ring rather than wrapping around it.
    final eaten = eatenFraction.clamp(0.0, 1.0);
    final plannedRoom = (1.0 - eaten).clamp(0.0, 1.0);
    final planned = plannedFraction.clamp(0.0, plannedRoom);

    if (planned > 0) {
      canvas.drawArc(
        arcRect,
        _startAngle + 2 * math.pi * eaten,
        2 * math.pi * planned,
        false,
        base..color = plannedColor,
      );
    }
    if (eaten > 0) {
      canvas.drawArc(
        arcRect,
        _startAngle,
        2 * math.pi * eaten,
        false,
        base..color = eatenColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.eatenFraction != eatenFraction ||
      old.plannedFraction != plannedFraction ||
      old.eatenColor != eatenColor;
}
