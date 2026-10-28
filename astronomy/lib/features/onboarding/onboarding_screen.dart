import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Onboarding', background: 'assets/backgrounds/bg-onboard.jpg', showBack: false);
}
