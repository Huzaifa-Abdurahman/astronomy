import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../astro/planets.dart';
import '../../astro/sky_track.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/motion.dart';

/// Top-down view of the inner solar system at [now]: the Sun, the orbits,
/// Earth and the planets where they really are, and the line of sight from
/// Earth to [planet]. The angle between that line and the Sun (the
/// elongation) is what decides whether the planet is an evening or a morning
/// object. "Play a year" runs the clock forward twelve months.
class SolarSystemView extends StatefulWidget {
  const SolarSystemView({super.key, required this.planet, required this.name, required this.now});

  final Planet planet;
  final String name;
  final DateTime now;

  /// Uranus and Neptune are not drawn (see [solarSystemAt]).
  static bool supports(Planet p) => p != Planet.uranus && p != Planet.neptune;

  @override
  State<SolarSystemView> createState() => _SolarSystemViewState();
}

class _SolarSystemViewState extends State<SolarSystemView> with SingleTickerProviderStateMixin {
  late final AnimationController _year = AnimationController(vsync: this, duration: const Duration(seconds: 16));
  bool _playing = false;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _year.repeat();
    } else {
      _year.stop();
      _year.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotionOf(context);
    return GlassCard(
      strongBorder: true,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(AppIcons.orbit, size: 20, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(child: Text('Why it is where it is', style: AppText.cardTitle)),
          if (!reduced)
            TextButton.icon(
              onPressed: _toggle,
              icon: Icon(_playing ? AppIcons.pause : AppIcons.play, size: 16, color: AppColors.cyan),
              label: Text(_playing ? 'Stop' : 'Play a year', style: AppText.body(13, weight: FontWeight.w600, color: AppColors.cyan)),
            ),
        ]),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _year,
          builder: (context, _) {
            final t = widget.now.add(Duration(minutes: (_year.value * 365.25 * 1440).round()));
            final system = solarSystemAt(t);
            final me = system.firstWhere((p) => p.planet == widget.planet);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TimeBuilder(
                restSeconds: 1,
                builder: (context, s, _) => AspectRatio(
                  aspectRatio: 1.15,
                  child: Semantics(
                    image: true,
                    label: 'Solar system diagram. ${elongationText(widget.name, me.elongationDeg)}',
                    child: CustomPaint(painter: _SystemPainter(system, widget.planet, s)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    _playing ? formatDay(t) : 'Today',
                    style: AppText.mono(12, color: AppColors.textMuted),
                  ),
                ),
                Text(
                  '${me.elongationDeg.abs().round()}° ${me.eveningSky ? 'east' : 'west'} of the Sun',
                  style: AppText.mono(12, weight: FontWeight.w500, color: AppColors.cyan),
                ),
              ]),
              const SizedBox(height: 6),
              GradientText(me.eveningSky ? 'Evening sky' : 'Morning sky', style: AppText.display(22)),
              const SizedBox(height: 4),
              Text(elongationText(widget.name, me.elongationDeg), style: AppText.body(13, color: AppColors.textSoft, height: 1.4)),
              const SizedBox(height: 6),
              Text(
                'Seen from above the Sun\'s north pole; the planets move anticlockwise. '
                'Orbits are drawn to a square-root scale so the inner planets stay visible.',
                style: AppText.caption,
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _SystemPainter extends CustomPainter {
  _SystemPainter(this.system, this.focus, this.seconds);

  final List<PlanetView> system;
  final Planet focus;
  final double seconds;

  static const _maxAu = 10.2; // just outside Saturn
  static const _colors = {
    Planet.mercury: Color(0xFFC9C9D6),
    Planet.venus: Color(0xFFFFD27A),
    Planet.mars: Color(0xFFFF8A7A),
    Planet.jupiter: Color(0xFFE8B98A),
    Planet.saturn: Color(0xFFE6D7A8),
  };
  static const _names = {
    Planet.mercury: 'Mercury',
    Planet.venus: 'Venus',
    Planet.mars: 'Mars',
    Planet.jupiter: 'Jupiter',
    Planet.saturn: 'Saturn',
  };

  double _r(double au, double scale) => math.sqrt(au / _maxAu) * scale;

  Offset _pos(PlanetView p, Offset c, double scale) {
    final r = _r(p.distanceFromSunAu, scale);
    final a = math.atan2(p.y, p.x);
    // Ecliptic +x to the right, +y up on screen (anticlockwise motion).
    return Offset(c.dx + r * math.cos(a), c.dy - r * math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / 2 - 16;
    final earth = system.firstWhere((p) => p.planet == null);
    final me = system.firstWhere((p) => p.planet == focus);
    final earthP = _pos(earth, c, scale), meP = _pos(me, c, scale);

    // Orbits (circles at the planet's current distance).
    for (final p in system) {
      final isFocus = p.planet == focus;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFocus ? 1.4 : 1
        ..color = (isFocus ? AppColors.cyan : AppColors.surfaceBorderStrong).withValues(alpha: isFocus ? 0.7 : 0.9);
      canvas.drawCircle(c, _r(p.distanceFromSunAu, scale), paint);
    }

    // Sun.
    canvas.drawCircle(c, 16, Paint()..color = AppColors.warm.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(c, 7, Paint()..color = AppColors.warm);

    // Lines of sight from Earth: to the Sun (dashed) and to the planet.
    _dashedLine(canvas, earthP, c, Paint()..color = AppColors.warm.withValues(alpha: 0.6)..strokeWidth = 1);
    final glow = 0.6 + 0.4 * pingPong(seconds, 2);
    canvas.drawLine(
      earthP,
      meP,
      Paint()
        ..shader = ui.Gradient.linear(earthP, meP, [AppColors.cyan, AppColors.violet])
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, 3 * glow),
    );

    // Elongation arc at Earth, from the Sun direction to the planet direction.
    final toSun = math.atan2(c.dy - earthP.dy, c.dx - earthP.dx);
    final toMe = math.atan2(meP.dy - earthP.dy, meP.dx - earthP.dx);
    var sweep = toMe - toSun;
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }
    while (sweep < -math.pi) {
      sweep += 2 * math.pi;
    }
    canvas.drawArc(
      Rect.fromCircle(center: earthP, radius: 22),
      toSun,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.cyan,
    );

    // Planets.
    for (final p in system) {
      final pos = _pos(p, c, scale);
      final isEarth = p.planet == null;
      final isFocus = p.planet == focus;
      final color = isEarth ? AppColors.planetBlue : _colors[p.planet]!;
      final radius = isEarth ? 5.0 : (isFocus ? 6.0 : 4.0);
      if (isFocus) {
        canvas.drawCircle(pos, radius + 7, Paint()..color = AppColors.cyan.withValues(alpha: 0.3 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(
          pos,
          radius + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.cyan,
        );
      }
      canvas.drawCircle(pos, radius, Paint()..color = color);
      if (p.planet == Planet.saturn) {
        canvas.drawOval(
          Rect.fromCenter(center: pos, width: radius * 4, height: radius * 1.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: 0.8),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: isEarth ? 'Earth' : _names[p.planet],
          style: AppText.mono(10, weight: isFocus ? FontWeight.w500 : FontWeight.w400, color: isFocus ? AppColors.text : AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos + Offset(radius + 4, -tp.height / 2));
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final dir = d / len;
    for (var s = 0.0; s < len; s += 8) {
      canvas.drawLine(a + dir * s, a + dir * math.min(s + 4, len), paint);
    }
  }

  @override
  bool shouldRepaint(_SystemPainter old) => true;
}
