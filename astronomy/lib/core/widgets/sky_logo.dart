import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'gradient_button.dart';

/// SkyGuide wordmark: a 4-point sparkle + "Sky" + gradient "Guide".
class SkyLogo extends StatelessWidget {
  const SkyLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AppText.display(size);
    return Semantics(
      label: 'SkyGuide',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Sparkle(size: size * 1.1),
        SizedBox(width: size * 0.3),
        Text('Sky', style: style),
        GradientText('Guide', style: style),
      ]),
    );
  }
}

/// Four-pointed star filled with the primary gradient and a soft glow.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _SparklePainter());
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final w = r * 0.22; // waist of each point
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, Paint()..shader = AppColors.primaryGradient.createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
