import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'cosmo.dart';
import 'gradient_button.dart';
import 'motion.dart';

/// Shimmering placeholder card used while data loads.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.height = 80, this.radius = 18});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: TimeBuilder(
        restSeconds: 0.7,
        builder: (_, s, _) {
          final x = -1.5 + 3 * loop01(s, 1.6);
          return Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.surfaceBorder),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: const [AppColors.surface, Color(0xFF1A2150), AppColors.surface],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A list of shimmer cards.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.height = 80});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < count; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: ShimmerBox(height: height)),
      ]);
}

/// Cosmo + message + optional action. Used for empty, error and no-location states.
class CosmoMessage extends StatelessWidget {
  const CosmoMessage({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.pose = CosmoPose.wave,
    this.cosmoSize = 110,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final CosmoPose pose;
  final double cosmoSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Cosmo(pose: pose, size: cosmoSize),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: AppText.section),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.textMuted, height: 1.4)),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          GradientButton(label: actionLabel!, onPressed: onAction),
        ],
      ]),
    );
  }
}
