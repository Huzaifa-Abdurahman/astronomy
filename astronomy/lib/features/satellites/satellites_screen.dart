import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class SatellitesScreen extends StatelessWidget {
  const SatellitesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Satellites', background: 'assets/backgrounds/bg-sat.jpg', showBack: false);
}
