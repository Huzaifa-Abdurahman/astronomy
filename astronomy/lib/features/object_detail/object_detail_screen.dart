import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class ObjectDetailScreen extends StatelessWidget {
  const ObjectDetailScreen({super.key, required this.objectId});

  final String objectId;
  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Object', background: 'assets/backgrounds/bg-detail.jpg', showBack: true);
}
