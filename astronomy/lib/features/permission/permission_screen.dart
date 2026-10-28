import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/cosmo.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/pulse_ring.dart';
import '../../core/widgets/twinkle_stars.dart';
import '../../data/location_service.dart';
import '../../data/prefs.dart';
import 'manual_location_sheet.dart';

/// Screen 2: location permission (CLAUDE.md §5, §8).
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _busy = false;

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.onboardingDone, true);
    if (mounted) context.go(Routes.home);
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    final status = await ref.read(locationProvider.notifier).requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    if (status == LocationStatus.ready || status == LocationStatus.locating) await _finish();
  }

  Future<void> _manual() async {
    if (await showManualLocationSheet(context)) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(locationProvider.select((s) => s.status));
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: HeroBackground(asset: 'assets/backgrounds/bg-permission.jpg', leftShade: false)),
        const TwinkleStars(count: 22, seed: 3),
        const LightBeams(top: 120),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.textSoft)),
              ),
            ),
            const Expanded(child: Center(child: Cosmo(pose: CosmoPose.wave, size: 140))),
            _Sheet(
              busy: _busy,
              status: status,
              onAllow: _allow,
              onManual: _manual,
              onOpenSettings: () => ref.read(locationProvider.notifier).openSettings(),
              onOpenLocationSettings: () => ref.read(locationProvider.notifier).openLocationSettings(),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.busy,
    required this.status,
    required this.onAllow,
    required this.onManual,
    required this.onOpenSettings,
    required this.onOpenLocationSettings,
  });

  final bool busy;
  final LocationStatus status;
  final VoidCallback onAllow;
  final VoidCallback onManual;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocationSettings;

  static const _benefits = [
    'Rise, peak and set times for your exact sky',
    'Point your phone straight at any object',
    'Satellite passes over your spot',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PulseRing(size: 30, child: Icon(AppIcons.mapPin, color: AppColors.cyan, size: 26)),
        const SizedBox(height: 10),
        Text('Where are you looking from?', style: AppText.display(26)),
        const SizedBox(height: 14),
        for (final b in _benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: const Icon(AppIcons.check, size: 15, color: AppColors.cyan),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(b, style: AppText.body(14, color: AppColors.textSoft))),
            ]),
          ),
        if (_message case final msg?) ...[
          const SizedBox(height: 4),
          Text(msg, style: AppText.body(13, color: AppColors.warm, height: 1.4)),
        ],
        const SizedBox(height: 14),
        if (status == LocationStatus.deniedForever)
          GradientButton(label: 'Open app settings', icon: AppIcons.settings, onPressed: onOpenSettings)
        else if (status == LocationStatus.serviceDisabled)
          GradientButton(label: 'Turn on location', icon: AppIcons.locateFixed, onPressed: onOpenLocationSettings)
        else
          GradientButton(
            label: busy ? 'Finding you…' : 'Allow while using the app',
            icon: AppIcons.locateFixed,
            onPressed: busy ? null : onAllow,
          ),
        const SizedBox(height: 10),
        GhostButton(label: 'Enter a city instead', icon: AppIcons.search, onPressed: onManual),
      ]),
    );
  }

  String? get _message => switch (status) {
        LocationStatus.denied => 'Location was not allowed. You can try again or enter a city instead.',
        LocationStatus.deniedForever => 'Location is blocked for SkyGuide. Enable it in settings, or enter a city.',
        LocationStatus.serviceDisabled => 'Your phone’s location service is off.',
        LocationStatus.error => 'Could not get a GPS fix. Try again outdoors, or enter a city.',
        _ => null,
      };
}
