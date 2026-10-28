import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Field of small star dots that fade 0.2 ↔ 1 over 3 s, staggered.
/// Place inside a [Stack]; it fills it.
class TwinkleStars extends StatelessWidget {
  const TwinkleStars({super.key, this.count = 28, this.seed = 7});

  final int count;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: TimeBuilder(
            restSeconds: 0.75,
            builder: (_, s, _) => CustomPaint(painter: _StarsPainter(count, seed, s)),
          ),
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.count, this.seed, this.seconds);

  final int count;
  final int seed;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed); // same layout every frame
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final pos = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 0.6 + rnd.nextDouble() * 1.2;
      final phase = rnd.nextDouble() * 3;
      final a = 0.2 + 0.8 * pingPong(seconds, 3, phase);
      paint.color = (i % 5 == 0 ? AppColors.cyan : AppColors.text).withValues(alpha: a);
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.seconds != seconds;
}
