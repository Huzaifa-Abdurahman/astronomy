import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../astro/angles.dart';
import '../../astro/models.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/sky_dome.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/catalog_repository.dart';
import '../../data/location_service.dart';
import '../../data/settings.dart';
import '../../data/sky_providers.dart';
import 'pointer_controller.dart';

/// Screen 6: point the phone at the object (CLAUDE.md §5, §8).
///
/// The sky dome turns with the compass so "straight ahead" is always at the
/// top; the arrow points at the target and the tilt bar compares the phone's
/// pitch with the target altitude. Light haptic within 3°, medium within 1°.
/// Without a compass (web, emulators) the dome stays north-up and the text
/// still tells you which way to face.
class PointerScreen extends ConsumerStatefulWidget {
  const PointerScreen({super.key, required this.objectId});

  final String objectId;

  @override
  ConsumerState<PointerScreen> createState() => _PointerScreenState();
}

class _PointerScreenState extends ConsumerState<PointerScreen> {
  final _zone = HapticZone();

  @override
  Widget build(BuildContext context) {
    final object = ref.watch(skyObjectProvider(widget.objectId));
    final live = ref.watch(liveSkyProvider(widget.objectId));
    final hasLocation = ref.watch(locationProvider.select((s) => s.hasLocation));
    final heading = ref.watch(headingProvider).value;
    final pitch = ref.watch(pitchProvider).value;
    final nightVision = ref.watch(settingsProvider.select((s) => s.nightVision));

    Widget body;
    if (object == null) {
      body = const CosmoMessage(title: 'Object not found');
    } else if (!hasLocation || live == null) {
      body = CosmoMessage(
        title: 'Location needed',
        message: 'Pointing needs to know where you are standing.',
        actionLabel: 'Enable location',
        onAction: () => context.push(Routes.permission),
      );
    } else {
      final delta = PointerDelta.from(
        targetAz: live.horizontal.azDeg,
        targetAlt: live.horizontal.altDeg,
        heading: heading,
        pitch: pitch,
      );
      final zone = _zone.update(delta);
      if (zone == 2) HapticFeedback.mediumImpact();
      if (zone == 1) HapticFeedback.lightImpact();
      body = _Pointer(object: object, target: live.horizontal, heading: heading, pitch: pitch, delta: delta);
    }

    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-pointer.jpg', leftShade: false),
        const LightBeams(top: 140),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(children: [
                IconSquareButton(icon: AppIcons.chevronLeft, semanticLabel: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                IconSquareButton(
                  icon: AppIcons.eye,
                  semanticLabel: nightVision ? 'Turn off night vision' : 'Turn on red night-vision mode',
                  active: nightVision,
                  color: nightVision ? AppColors.red : AppColors.text,
                  onPressed: () => ref.read(settingsProvider.notifier).setNightVision(!nightVision),
                ),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
      ]),
    );
  }
}

class _Pointer extends StatelessWidget {
  const _Pointer({required this.object, required this.target, required this.heading, required this.pitch, required this.delta});

  final SkyObject object;
  final HorizontalPosition target;
  final double? heading;
  final double? pitch;
  final PointerDelta delta;

  @override
  Widget build(BuildContext context) {
    final up = target.isUp;
    final (String head, String sub) = _instruction(up);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(object.name, style: AppText.body(14, weight: FontWeight.w600, color: AppColors.textSoft)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: GradientText(
            head,
            key: ValueKey(head),
            style: AppText.display(delta.onTarget ? 34 : 40),
            gradient: delta.onTarget ? const LinearGradient(colors: [AppColors.cyan, AppColors.cyan]) : AppColors.primaryGradient,
          ),
        ),
        const SizedBox(height: 4),
        Text(sub, style: AppText.body(14, color: AppColors.textSoft, height: 1.35)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Stack(alignment: Alignment.topCenter, children: [
              TimeBuilder(
                restSeconds: 0.5,
                builder: (_, s, _) => SkyDome(
                  headingDeg: heading ?? 0,
                  arrowAzDeg: target.azDeg,
                  cosmoPose: CosmoPose.telescope,
                  markers: [
                    DomeMarker(
                      altDeg: target.altDeg,
                      azDeg: target.azDeg,
                      pulse: true,
                      size: 8,
                      color: delta.onTarget ? AppColors.cyan : AppColors.violetSoft,
                      label: object.name,
                    ),
                  ],
                  seconds: s,
                  semanticLabel: 'Compass. $head. $sub',
                ),
              ),
              // "You are facing this way" notch at the top of the dome.
              if (heading != null)
                const Positioned(top: 0, child: Icon(AppIcons.chevronDown, size: 18, color: AppColors.cyan)),
            ]),
          ),
          const SizedBox(width: 8),
          _TiltBar(pitch: pitch, targetAlt: target.altDeg, onTarget: delta.onTarget),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Readout('Phone heading', heading == null ? 'no compass' : '${heading!.round()}° ${compass16(heading!)}')),
          Expanded(child: _Readout('Target az', '${target.azDeg.round()}° ${compass16(target.azDeg)}')),
          Expanded(child: _Readout('Target alt', formatDeg(target.altDeg, digits: 0))),
        ]),
        const SizedBox(height: 10),
        if (heading == null || pitch == null)
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(AppIcons.info, size: 18, color: AppColors.warm),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  heading == null
                      ? 'No compass on this device, so the map stays north-up. Face ${compass16(target.azDeg)} and tilt your head up ${target.altDeg.round()}°.'
                      : 'No tilt sensor: use the altitude readout.',
                  style: AppText.body(13, color: AppColors.textSoft, height: 1.35),
                ),
              ),
            ]),
          ),
        if (!up) ...[
          const SizedBox(height: 10),
          const StatusPill(label: 'Below the horizon right now', color: AppColors.warm, icon: AppIcons.moon),
        ],
        const SizedBox(height: 14),
        GhostButton(label: 'Show the math', icon: AppIcons.sigma, onPressed: () => context.push(Routes.math(object.id))),
      ]),
    );
  }

  (String, String) _instruction(bool up) {
    if (!up) {
      return ('Below horizon', 'It is ${(-target.altDeg).round()}° under the ${compass16(target.azDeg)} horizon. Check the object page for when it rises.');
    }
    final az = delta.azDeg, alt = delta.altDeg;
    if (az == null) {
      return ('Face ${compass16(target.azDeg)}', 'Then look up ${target.altDeg.round()}°. Hold the phone upright with the camera towards the sky.');
    }
    if (delta.onTarget) {
      return ('On target', 'You are pointing straight at ${object.name}.');
    }
    if (az.abs() > 3) {
      return ('Turn ${az > 0 ? 'right' : 'left'} ${az.abs().round()}°', alt == null ? 'Then look up ${target.altDeg.round()}°.' : _tiltText(alt));
    }
    return ('Tilt ${alt! > 0 ? 'up' : 'down'} ${alt.abs().round()}°', 'Direction is right. ${_tiltText(alt)}');
  }

  String _tiltText(double alt) => alt.abs() <= 3 ? 'Height is right too.' : 'Tilt the phone ${alt > 0 ? 'up' : 'down'} ${alt.abs().round()}°.';
}

/// Vertical bar from horizon (bottom) to zenith (top) with the phone's pitch
/// and the target altitude.
class _TiltBar extends StatelessWidget {
  const _TiltBar({required this.pitch, required this.targetAlt, required this.onTarget});

  final double? pitch;
  final double targetAlt;
  final bool onTarget;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tilt: ${pitch == null ? 'unknown' : '${pitch!.round()} degrees'}, target ${targetAlt.round()} degrees',
      child: SizedBox(
        width: 44,
        height: 220,
        child: LayoutBuilder(builder: (context, c) {
          double y(double alt) => c.maxHeight - (alt.clamp(0.0, 90.0) / 90) * c.maxHeight;
          return Stack(alignment: Alignment.topCenter, children: [
            Positioned.fill(
              left: 18,
              right: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.surfaceBorderStrong),
                ),
              ),
            ),
            for (final alt in const [0.0, 30.0, 60.0, 90.0])
              Positioned(
                top: y(alt) - 6,
                right: 0,
                child: Text('${alt.toInt()}', style: AppText.mono(9, color: AppColors.textMuted)),
              ),
            Positioned(
              top: y(targetAlt) - 1.5,
              left: 12,
              right: 12,
              child: Container(height: 3, color: onTarget ? AppColors.cyan : AppColors.violetSoft),
            ),
            if (pitch != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                top: y(pitch!) - 7,
                left: 8,
                child: Container(
                  width: 28,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: AppColors.cyanGlow(0.5),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.body(11, color: AppColors.textMuted)),
        Text(value, style: AppText.mono(14, weight: FontWeight.w500)),
      ]);
}
