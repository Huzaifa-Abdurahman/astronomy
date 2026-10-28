import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Location', background: 'assets/backgrounds/bg-permission.jpg', showBack: false);
}
