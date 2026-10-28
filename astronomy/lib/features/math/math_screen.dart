import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class MathScreen extends StatelessWidget {
  const MathScreen({super.key, required this.objectId});

  final String objectId;
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'The math', background: 'assets/backgrounds/bg-math.jpg', showBack: true);
}
