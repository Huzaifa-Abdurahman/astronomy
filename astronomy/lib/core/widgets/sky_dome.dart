import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../astro/angles.dart';
import '../../astro/sky_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'cosmo.dart';

/// A path drawn on the dome, e.g. tonight's track or a satellite pass.
class DomeTrack {
  const DomeTrack({
    required this.points,
    this.color = AppColors.cyan,
    this.progress = 1,
    this.highlight,
    this.dashed = false,
  });

  final List<SkyPoint> points;
  final Color color;

  /// 0…1 draws the path in from its start (chart draw-in effect).
  final double progress;

  /// Time span painted brighter and thicker (e.g. the dark-sky window).
  final ({DateTime start, DateTime end})? highlight;
  final bool dashed;
}

/// A marker on the dome.
class DomeMarker {
  const DomeMarker({
    required this.altDeg,
    required this.azDeg,
    this.color = AppColors.cyan,
    this.label,
    this.pulse = false,
    this.size = 7,
    this.star = false,
  });

  final double altDeg;
  final double azDeg;
  final Color color;
  final String? label;

  /// Expanding rings (live position).
  final bool pulse;
  final double size;

  /// Draw a four-point sparkle instead of a dot (peak / best moment).
  final bool star;
}

/// Top-down view of the observer's sky: the zenith at the centre, the horizon
/// on the rim, compass points around it (CLAUDE.md §4.4 "pulse rings").
///
/// Everything drawn on it comes from [domeXy], so a point's distance from the
/// centre is its altitude and its bearing from the top is its azimuth. With
/// [headingDeg] the dome turns so the direction the phone faces is at the top.
///
/// [seconds] drives the loops (pulse rings, arrow glow); pass a constant for a
/// static frame when motion is reduced.
class SkyDome extends StatelessWidget {
  const SkyDome({
    super.key,
    this.tracks = const [],
    this.markers = const [],
    this.headingDeg = 0,
    this.arrowAzDeg,
    this.arrowProgress = 1,
    this.gaugeAltDeg,
    this.gaugeProgress = 1,
    this.seconds = 0,
    this.showCosmo = true,
    this.cosmoPose = CosmoPose.telescope,
    this.semanticLabel,
  });

  final List<DomeTrack> tracks;
  final List<DomeMarker> markers;
  final double headingDeg;

  /// Direction arrow from the centre; [arrowProgress] sweeps it from north
  /// (0) to [arrowAzDeg] (1).
  final double? arrowAzDeg;
  final double arrowProgress;

  /// Side-view altitude gauge in the corner; [gaugeProgress] fills it.
  final double? gaugeAltDeg;
  final double gaugeProgress;

  final double seconds;
  final bool showCosmo;
  final CosmoPose cosmoPose;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dome = AspectRatio(
      aspectRatio: 1,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _DomePainter(this)),
        if (showCosmo)
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.2,
              child: FittedBox(child: Cosmo(pose: cosmoPose, size: 48, semanticLabel: 'You, in the middle of your sky')),
            ),
          ),
      ]),
    );
    return semanticLabel == null ? dome : Semantics(label: semanticLabel, image: true, child: dome);
  }
}

class _DomePainter extends CustomPainter {
  _DomePainter(this.w);

  final SkyDome w;

  static const _cardinals = ['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rim = math.min(size.width, size.height) / 2 - 22; // room for labels
    Offset xy(double alt, double az) {
      final p = domeXy(alt, az, headingDeg: w.headingDeg);
      return Offset(c.dx + p.x * rim, c.dy + p.y * rim);
    }

    _paintSky(canvas, c, rim);
    _paintGrid(canvas, c, rim);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: rim + 1)));
    for (final t in w.tracks) {
      _paintTrack(canvas, t, xy);
    }
    canvas.restore();

    if (w.arrowAzDeg != null) _paintArrow(canvas, c, rim, xy);
    for (final m in w.markers) {
      _paintMarker(canvas, m, xy);
    }
    _paintCompass(canvas, c, rim);
    if (w.gaugeAltDeg != null) _paintGauge(canvas, size);
  }

  void _paintSky(Canvas canvas, Offset c, double rim) {
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..shader = ui.Gradient.radial(c, rim, [
          const Color(0xFF141B4A),
          const Color(0xFF0B1035),
          AppColors.bg,
        ], [
          0,
          0.6,
          1,
        ]),
    );
    // Faint horizon glow.
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.cyan.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _paintGrid(Canvas canvas, Offset c, double rim) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.surfaceBorderStrong.withValues(alpha: 0.9);
    for (final alt in const [30.0, 60.0]) {
      _dashedCircle(canvas, c, rim * (90 - alt) / 90, ring);
    }
    canvas.drawCircle(c, rim, ring..color = AppColors.inputBorder);
    // Altitude ring labels, on the line towards the top-right.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final alt in const [30.0, 60.0]) {
      final r = rim * (90 - alt) / 90;
      tp.text = TextSpan(text: '${alt.toInt()}°', style: AppText.mono(9, color: AppColors.textMuted));
      tp.layout();
      final p = Offset(c.dx + r * math.sin(math.pi / 4), c.dy - r * math.cos(math.pi / 4));
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    // Cross hairs through the zenith.
    final hair = Paint()
      ..strokeWidth = 1
      ..color = AppColors.surfaceBorder.withValues(alpha: 0.8);
    for (var k = 0; k < 2; k++) {
      final a = (w.headingDeg + 90 * k) * degToRad;
      canvas.drawLine(c + Offset(math.sin(a), -math.cos(a)) * rim, c - Offset(math.sin(a), -math.cos(a)) * rim, hair);
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const n = 60;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), 2 * math.pi * i / n, 2 * math.pi / n, false, paint);
    }
  }

  void _paintCompass(Canvas canvas, Offset c, double rim) {
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textMuted;
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (var i = 0; i < 16; i++) {
      final az = i * 22.5;
      final a = (az - w.headingDeg) * degToRad;
      final dir = Offset(math.sin(a), -math.cos(a));
      final major = i % 4 == 0;
      canvas.drawLine(c + dir * rim, c + dir * (rim + (major ? 7 : 4)), tick..color = major ? AppColors.textSoft : AppColors.textMuted);
      if (major) {
        final label = _cardinals[i ~/ 4];
        final north = i == 0;
        tp.text = TextSpan(
          text: label,
          style: AppText.body(12, weight: FontWeight.w700, color: north ? AppColors.red : AppColors.textSoft),
        );
        tp.layout();
        final p = c + dir * (rim + 15);
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _paintTrack(Canvas canvas, DomeTrack t, Offset Function(double, double) xy) {
    if (t.points.length < 2) return;
    final n = ((t.points.length - 1) * t.progress.clamp(0.0, 1.0)).floor();
    if (n < 1) return;
    final dim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = t.color.withValues(alpha: 0.35);
    final bright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = t.color
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    final below = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = t.color.withValues(alpha: 0.15);

    for (var i = 0; i < n; i++) {
      final a = t.points[i], b = t.points[i + 1];
      if (t.dashed && i.isOdd) continue;
      final pa = xy(a.altDeg, a.azDeg), pb = xy(b.altDeg, b.azDeg);
      final up = a.isUp || b.isUp;
      final h = t.highlight;
      final hot = h != null && !a.time.isBefore(h.start) && !b.time.isAfter(h.end);
      canvas.drawLine(pa, pb, !up ? below : (hot ? bright : dim));
    }
    // Draw-in head: a small bright dot at the leading edge while animating.
    if (t.progress < 1) {
      final p = t.points[n];
      if (p.isUp) canvas.drawCircle(xy(p.altDeg, p.azDeg), 3, Paint()..color = t.color);
    }
  }

  void _paintArrow(Canvas canvas, Offset c, double rim, Offset Function(double, double) xy) {
    final target = w.arrowAzDeg!;
    final az = norm180(target) * w.arrowProgress.clamp(0.0, 1.0); // sweep the short way from north
    final a = (az - w.headingDeg) * degToRad;
    final dir = Offset(math.sin(a), -math.cos(a));
    final start = c + dir * (rim * 0.16);
    final end = c + dir * (rim * 0.92);
    final glow = 0.6 + 0.4 * (0.5 - 0.5 * math.cos(2 * math.pi * w.seconds / 2));
    final shader = ui.Gradient.linear(start, end, [AppColors.cyan.withValues(alpha: 0.2), AppColors.cyan, AppColors.violet], [0, 0.55, 1]);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..shader = shader
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, 4 * glow),
    );
    // Arrow head.
    final side = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - dir.dx * 12 + side.dx * 6, end.dy - dir.dy * 12 + side.dy * 6)
      ..lineTo(end.dx - dir.dx * 12 - side.dx * 6, end.dy - dir.dy * 12 - side.dy * 6)
      ..close();
    canvas.drawPath(head, Paint()..color = AppColors.violet);
  }

  void _paintMarker(Canvas canvas, DomeMarker m, Offset Function(double, double) xy) {
    final p = xy(m.altDeg, m.azDeg);
    if (m.altDeg < -2) return;
    if (m.pulse) {
      for (final offset in const [0.0, 1.0]) {
        final t = ((w.seconds + offset) % 2) / 2;
        canvas.drawCircle(
          p,
          m.size * (0.6 + 1.6 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = m.color.withValues(alpha: (1 - t) * 0.8),
        );
      }
    }
    if (m.star) {
      final r = m.size * 1.6;
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final rr = i.isEven ? r : r * 0.4;
        final a = i * math.pi / 4;
        final v = Offset(p.dx + rr * math.sin(a), p.dy - rr * math.cos(a));
        i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = m.color..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
    } else {
      canvas.drawCircle(p, m.size + 3, Paint()..color = m.color.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(p, m.size / 2 + 1.5, Paint()..color = m.color);
      canvas.drawCircle(
        p,
        m.size / 2 + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.text,
      );
    }
    if (m.label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: AppText.mono(10, weight: FontWeight.w500, color: m.color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bg = Rect.fromCenter(center: p + Offset(0, -m.size - 12), width: tp.width + 8, height: tp.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(bg, const Radius.circular(6)), Paint()..color = AppColors.bg.withValues(alpha: 0.75));
      tp.paint(canvas, bg.topLeft + const Offset(4, 2));
    }
  }

  /// Quarter-circle side view in the bottom-left: horizon → zenith.
  void _paintGauge(Canvas canvas, Size size) {
    const r = 46.0;
    final o = Offset(14, size.height - 14);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.surfaceBorderStrong;
    canvas.drawArc(Rect.fromCircle(center: o, radius: r), -math.pi / 2, math.pi / 2, false, arc);
    canvas.drawLine(o, o + const Offset(r, 0), arc);
    final alt = (w.gaugeAltDeg!.clamp(0.0, 90.0)) * w.gaugeProgress.clamp(0.0, 1.0);
    final a = alt * degToRad;
    final tip = o + Offset(r * math.cos(a), -r * math.sin(a));
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r),
      0,
      -a,
      true,
      Paint()..color = AppColors.cyan.withValues(alpha: 0.12),
    );
    canvas.drawLine(
      o,
      tip,
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(o, tip, [AppColors.cyan, AppColors.violet]),
    );
    canvas.drawCircle(tip, 3.5, Paint()..color = AppColors.text);
    final tp = TextPainter(
      text: TextSpan(
        text: '${alt.round()}°',
        style: AppText.mono(11, weight: FontWeight.w500, color: AppColors.cyan),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o + Offset(r + 6, -tp.height - 2));
  }

  @override
  bool shouldRepaint(_DomePainter old) => true;
}
