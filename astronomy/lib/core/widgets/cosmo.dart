import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

enum CosmoPose { wave, telescope, board, phone, idle }

/// Cosmo the astronaut mascot (CLAUDE.md §4.5).
///
/// Painted from the same shapes as `assets/cosmo/cosmo.svg` (100×110 viewBox)
/// so the right arm and props can animate on their own. Every pose floats
/// ±7 px with ±4° rotation over 4 s and the antenna tip blinks every 2 s.
class Cosmo extends StatelessWidget {
  const Cosmo({super.key, this.pose = CosmoPose.wave, this.size = 120, this.semanticLabel = 'Cosmo the astronaut'});

  final CosmoPose pose;

  /// Width in logical pixels; height follows the drawing's aspect ratio.
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: TimeBuilder(
        builder: (_, s, _) => CustomPaint(
          size: Size(size, size * _CosmoPainter.viewH / _CosmoPainter.viewW),
          painter: _CosmoPainter(pose, s),
        ),
      ),
    );
  }
}

class _CosmoPainter extends CustomPainter {
  _CosmoPainter(this.pose, this.t);

  final CosmoPose pose;
  final double t;

  // The SVG is 100×110; we add margin so props held to the right fit.
  static const viewX = -6.0, viewY = -4.0, viewW = 124.0, viewH = 122.0;

  static const _white = AppColors.text;
  static const _suitShade = Color(0xFF8C96C8);
  static const _boot = Color(0xFF5B66A6);
  static const _rim = Color(0xFFC9D0EE);
  static const _visor = Color(0xFF0B1240);

  final _p = Paint()..isAntiAlias = true;

  void _rrect(Canvas c, double x, double y, double w, double h, double r, Color color) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), _p..color = color..style = PaintingStyle.fill);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / viewW;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-viewX, -viewY);

    // Whole-body float: ±7 px and ±4° over 4 s, pivoting about the torso.
    final float = math.sin(2 * math.pi * t / 4);
    canvas.translate(0, 7 * float);
    canvas.translate(50, 60);
    canvas.rotate(4 * math.pi / 180 * math.sin(2 * math.pi * t / 4 + 0.8));
    canvas.translate(-50, -60);

    // Body (back to front, same order as the SVG).
    _rrect(canvas, 24, 50, 52, 38, 12, _suitShade); // backpack
    _rrect(canvas, 32, 54, 36, 34, 12, _white); // torso
    _rrect(canvas, 43, 64, 14, 9, 2, AppColors.cyan); // chest panel
    _rrect(canvas, 36, 84, 11, 14, 5, _white); // legs
    _rrect(canvas, 53, 84, 11, 14, 5, _white);
    _rrect(canvas, 34, 96, 14, 7, 3, _boot); // boots
    _rrect(canvas, 52, 96, 14, 7, 3, _boot);

    // Left arm, fixed at 30°.
    canvas.save();
    canvas.translate(27, 63);
    canvas.rotate(30 * math.pi / 180);
    _rrect(canvas, -7, -5, 14, 10, 5, _white);
    canvas.restore();

    _paintRightArm(canvas);
    _paintHead(canvas);
    canvas.restore();
  }

  void _paintRightArm(Canvas canvas) {
    const shoulder = Offset(75, 60);
    double armDeg;
    switch (pose) {
      case CosmoPose.wave:
        armDeg = 22 * pingPong(t, 1.6);
      case CosmoPose.telescope:
        armDeg = 8 * math.sin(2 * math.pi * t / 3);
      case CosmoPose.board:
        // Quick tap forward then return, once per 1.2 s.
        final phase = loop01(t, 1.2);
        armDeg = phase < 0.25 ? -14 * math.sin(phase / 0.25 * math.pi) : 0;
      case CosmoPose.phone:
        armDeg = -4 + 3 * math.sin(2 * math.pi * t / 3);
      case CosmoPose.idle:
        armDeg = 0;
    }
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(armDeg * math.pi / 180);
    canvas.translate(-shoulder.dx, -shoulder.dy);

    switch (pose) {
      case CosmoPose.telescope:
        _paintTelescope(canvas);
      case CosmoPose.board:
        _paintBoard(canvas);
      case CosmoPose.phone:
        _paintPhone(canvas);
      case CosmoPose.wave:
      case CosmoPose.idle:
        break;
    }
    _rrect(canvas, 70, 42, 10, 20, 5, _white); // arm
    canvas.drawCircle(const Offset(75, 40), 5, _p..color = _boot); // glove
    canvas.restore();
  }

  void _paintTelescope(Canvas canvas) {
    canvas.save();
    canvas.translate(75, 40);
    canvas.rotate(-50 * math.pi / 180);
    final tube = Path()
      ..moveTo(-6, -3.2)
      ..lineTo(28, -4.6)
      ..lineTo(28, 4.6)
      ..lineTo(-6, 3.2)
      ..close();
    canvas.drawPath(tube, _p..color = _rim);
    _rrect(canvas, 26, -5.5, 6, 11, 2, AppColors.violet);
    canvas.drawCircle(const Offset(32, 0), 3, _p..color = AppColors.cyan.withValues(alpha: 0.85));
    canvas.restore();
  }

  void _paintBoard(Canvas canvas) {
    const rect = Rect.fromLTWH(78, 18, 30, 24);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rr, _p..color = AppColors.cyan.withValues(alpha: 0.22));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.cyan,
    );
    final tp = TextPainter(
      text: const TextSpan(text: '∑', style: TextStyle(color: AppColors.cyan, fontSize: 17, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintPhone(Canvas canvas) {
    const rect = Rect.fromLTWH(73, 18, 13, 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(6)),
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.18 + 0.12 * pingPong(t, 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    _rrect(canvas, rect.left, rect.top, rect.width, rect.height, 3, _visor);
    _rrect(canvas, rect.left + 1.5, rect.top + 2, rect.width - 3, rect.height - 4, 2, AppColors.cyan.withValues(alpha: 0.75));
  }

  void _paintHead(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 34), 24, _p..color = _white);
    canvas.drawCircle(
      const Offset(50, 34),
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _rim,
    );
    _rrect(canvas, 34, 23, 32, 23, 11, _visor);
    canvas.drawOval(Rect.fromCenter(center: const Offset(41, 29), width: 10, height: 6), _p..color = AppColors.cyan.withValues(alpha: 0.7));
    canvas.drawCircle(const Offset(45, 35), 2.2, _p..color = AppColors.cyan);
    canvas.drawCircle(const Offset(55, 35), 2.2, _p..color = AppColors.cyan);
    canvas.drawPath(
      Path()
        ..moveTo(46, 40)
        ..quadraticBezierTo(50, 43, 54, 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.cyan,
    );
    canvas.drawLine(const Offset(50, 10), const Offset(50, 5), Paint()..color = _rim..strokeWidth = 2);
    // Antenna tip blinks over 2 s.
    final blink = 0.35 + 0.65 * pingPong(t, 2);
    canvas.drawCircle(
      const Offset(50, 4),
      5,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.35 * blink)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(const Offset(50, 4), 3, _p..color = AppColors.violet.withValues(alpha: blink));
  }

  @override
  bool shouldRepaint(_CosmoPainter old) => old.t != t || old.pose != pose;
}
