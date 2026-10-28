import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class TonightScreen extends StatelessWidget {
  const TonightScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: "Tonight's plan", background: 'assets/backgrounds/bg-tonight.jpg', showBack: true);
}
