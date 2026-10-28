import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Translucent navy card with a 1 px border (CLAUDE.md §4.3).
///
/// [accent] switches to the cyan→violet accent fill with a soft cyan glow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.accent = false,
    this.strongBorder = false,
    this.borderColor,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool accent;
  final bool strongBorder;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: borderColor ??
            (accent
                ? AppColors.accentBorder
                : strongBorder
                    ? AppColors.surfaceBorderStrong
                    : AppColors.surfaceBorder),
      ),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }
    content = Material(type: MaterialType.transparency, child: content);

    final card = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: accent ? null : AppColors.surface,
        gradient: accent ? AppColors.accentGradient : null,
        shadows: accent ? [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.28), blurRadius: 22)] : null,
      ),
      child: content,
    );
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, button: onTap != null, child: card);
  }
}
