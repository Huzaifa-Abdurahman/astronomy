import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// The two animated diagonal "light beam" bands (CLAUDE.md §4.4).
///
/// A wide soft band and a 2 px bright line, rotated about −22°. Each slides
/// ±24 px and pulses opacity 0.25 ↔ 1 over 5 s; the line runs 2.5 s behind.
/// Place inside a [Stack]; it fills it and ignores pointer events.
class LightBeams extends StatelessWidget {
  const LightBeams({super.key, this.top = 140, this.angleDeg = -22});

  /// Vertical position of the wide band's top edge.
  final double top;
  final double angleDeg;

  static const _bandGradient = LinearGradient(colors: [
    Colors.transparent,
    Color(0x293EE7FF), // cyan @16%
    Color(0x1FA06BFF), // violet @12%
    Colors.transparent,
  ], stops: [0, 0.45, 0.65, 1]);

  static const _lineGradient = LinearGradient(colors: [
    Colors.transparent,
    AppColors.cyan,
    AppColors.violet,
    Colors.transparent,
  ], stops: [0, 0.4, 0.7, 1]);

  @override
  Widget build(BuildContext context) {
    final angle = angleDeg * 3.1415926535 / 180;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: TimeBuilder(
            restSeconds: 1.25, // a pleasant mid-pulse frame for reduced motion
            builder: (context, s, _) {
              final bandT = pingPong(s, 5);
              final lineT = pingPong(s, 5, 2.5);
              return Stack(clipBehavior: Clip.none, children: [
                _beam(top: top, height: 100, angle: angle, t: bandT, child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: TileMode.decal),
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: _bandGradient)),
                )),
                _beam(top: top + 38, height: 2, angle: angle, t: lineT, child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _lineGradient, boxShadow: [
                    BoxShadow(color: AppColors.cyan.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 3),
                  ]),
                )),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _beam({required double top, required double height, required double angle, required double t, required Widget child}) {
    return Positioned(
      left: -120,
      right: -120,
      top: top,
      height: height,
      child: Transform.rotate(
        angle: angle,
        child: Transform.translate(
          offset: Offset(lerpDouble(-24, 24, t)!, 0),
          child: Opacity(opacity: lerpDouble(0.25, 1, t)!, child: child),
        ),
      ),
    );
  }
}
