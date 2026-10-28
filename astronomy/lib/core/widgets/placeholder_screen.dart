import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'cosmo.dart';
import 'hero_background.dart';
import 'light_beams.dart';

/// Temporary scaffold for screens that are not built yet (phase 1 skeleton).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.background, this.showBack = false});

  final String title;
  final String background;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        HeroBackground(asset: background, height: 340),
        const LightBeams(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showBack) const BackButton(color: AppColors.text),
              const SizedBox(height: 12),
              Text(title, style: AppText.screenTitle),
              const Spacer(),
              const Center(child: Cosmo(pose: CosmoPose.board)),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }
}
