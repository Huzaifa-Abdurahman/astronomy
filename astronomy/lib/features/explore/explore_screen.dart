import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.initialFilter});

  final String? initialFilter;
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Explore', background: 'assets/backgrounds/bg-explore.jpg', showBack: false);
}
