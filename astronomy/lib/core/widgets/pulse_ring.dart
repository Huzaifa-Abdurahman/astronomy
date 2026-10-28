import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Live marker: a solid dot with rings that expand 0.6 → 2× and fade over 2 s.
class PulseRing extends StatelessWidget {
  const PulseRing({super.key, this.size = 18, this.color = AppColors.cyan, this.child});

  /// Diameter of the solid centre.
  final double size;
  final Color color;

  /// Optional widget drawn instead of the solid dot (e.g. an icon).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final box = size * 2.2;
    return ExcludeSemantics(
      child: SizedBox(
        width: box,
        height: box,
        child: TimeBuilder(
          restSeconds: 0.6,
          builder: (_, s, _) => Stack(alignment: Alignment.center, children: [
            for (final offset in const [0.0, 1.0]) _ring(loop01(s, 2, offset)),
            child ??
                Container(
                  width: size * 0.6,
                  height: size * 0.6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.text, width: 2),
                    boxShadow: [BoxShadow(color: color, blurRadius: 10)],
                  ),
                ),
          ]),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final scale = 0.6 + 1.4 * t;
    return Container(
      width: size * scale,
      height: size * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: (1 - t) * 0.8), width: 1.5),
      ),
    );
  }
}
