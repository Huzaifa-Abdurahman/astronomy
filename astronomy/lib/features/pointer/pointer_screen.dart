import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class PointerScreen extends StatelessWidget {
  const PointerScreen({super.key, required this.objectId});

  final String objectId;
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Point to sky', background: 'assets/backgrounds/bg-pointer.jpg', showBack: true);
}
