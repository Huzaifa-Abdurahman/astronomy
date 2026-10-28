import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Dark-sky spots', background: 'assets/backgrounds/bg-nearby.jpg', showBack: false);
}
