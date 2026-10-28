import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Hero image with the slow Ken Burns drift and a fade into [AppColors.bg].
///
/// Use [height] for a top hero, or leave it null to fill the parent (full-
/// screen backgrounds). [flip] mirrors the image horizontally (Home hero).
class HeroBackground extends StatelessWidget {
  const HeroBackground({
    super.key,
    required this.asset,
    this.height,
    this.flip = false,
    this.leftShade = true,
    this.alignment = Alignment.center,
  });

  final String asset;
  final double? height;
  final bool flip;
  final bool leftShade;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = TimeBuilder(
      builder: (context, s, child) {
        final t = pingPong(s, 20);
        final scale = lerpDouble(1.04, 1.10, t)!;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(0, -6 * t, 0, 1)
            ..scaleByDouble(flip ? -scale : scale, scale, 1, 1),
          child: child,
        );
      },
      child: Image.asset(asset, fit: BoxFit.cover, alignment: alignment, width: double.infinity, height: double.infinity),
    );

    final content = Stack(fit: StackFit.expand, children: [
      ClipRect(child: image),
      // Vertical fade so the content below stays readable.
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C070A1F), Color(0x26070A1F), Color(0x8C070A1F), AppColors.bg],
            stops: [0, 0.3, 0.7, 1],
          ),
        ),
      ),
      if (leftShade)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x8C070A1F), Colors.transparent],
              stops: [0, 0.65],
            ),
          ),
        ),
    ]);

    return ExcludeSemantics(child: height == null ? content : SizedBox(height: height, width: double.infinity, child: content));
  }
}
