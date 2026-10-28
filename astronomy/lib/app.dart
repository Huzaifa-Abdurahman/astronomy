import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/settings.dart';

class SkyGuideApp extends ConsumerWidget {
  const SkyGuideApp({super.key});

  /// Night-vision mode: map luminance to red only, so the screen does not
  /// spoil dark-adapted eyes.
  static const _redOnly = ColorFilter.matrix([
    0.30, 0.59, 0.11, 0, 0, //
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightVision = ref.watch(settingsProvider.select((s) => s.nightVision));
    return MaterialApp.router(
      title: 'SkyGuide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          nightVision ? ColorFiltered(colorFilter: _redOnly, child: child) : child ?? const SizedBox.shrink(),
    );
  }
}
