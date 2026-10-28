import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Home', background: 'assets/backgrounds/bg-home.jpg', showBack: false);
}
