import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import 'motion.dart';

/// Small rounded tag, e.g. "Rises later", "LIVE", "best sky".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon, this.live = false});

  final String label;
  final Color color;
  final IconData? icon;

  /// Shows a blinking dot before the label.
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (live)
          TimeBuilder(
            builder: (_, s, _) => Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + 0.65 * pingPong(s, 1.4)),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)],
              ),
            ),
          ),
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: AppText.body(12, weight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
