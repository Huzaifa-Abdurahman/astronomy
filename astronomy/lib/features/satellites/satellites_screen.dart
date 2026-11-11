import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../astro/angles.dart';
import '../../astro/orbit.dart';
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
import '../../core/widgets/pulse_ring.dart';
import '../../core/widgets/sky_nav_bar.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/celestrak_api.dart';
import '../../data/location_service.dart';
import '../../data/n2yo_api.dart';
import 'pass_arc_view.dart';
import 'satellites_repository.dart';

/// Screen 8: live satellites and their next visible passes.
///
/// Positions and passes come from N2YO; orbit elements from CelesTrak, which
/// is also the fallback when N2YO is unavailable (no key, offline, or in a
/// browser, where N2YO's missing CORS headers block requests).
class SatellitesScreen extends ConsumerWidget {
  const SatellitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider.select((s) => s.location));
    final selected = ref.watch(selectedSatelliteProvider);
    final now = ref.watch(satClockProvider).value ?? DateTime.now().toUtc();
    final live = ref.watch(satTrackProvider(selected)).value?.isLive(now) ?? false;

    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-sat.jpg', height: 300),
        const Positioned(top: 0, left: 0, right: 0, height: 260, child: _OrbitArc()),
        const LightBeams(top: 120),
        SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(child: Text('Satellites', style: AppText.screenTitle)),
                  if (location != null)
                    live
                        ? const StatusPill(label: 'LIVE', color: AppColors.cyan, live: true)
                        : const StatusPill(label: 'ORBIT DATA', color: AppColors.violetSoft),
                ]),
                const SizedBox(height: 4),
                Text(
                  location == null ? 'Public satellites overhead' : 'Over ${location.displayLabel}',
                  style: AppText.body(14, color: AppColors.textSoft),
                ),
                const SizedBox(height: 110),
              ]),
            ),
            if (location == null)
              SliverToBoxAdapter(
                child: CosmoMessage(
                  title: 'Location needed',
                  message: 'Passes depend on where you are standing.',
                  actionLabel: 'Enable location',
                  onAction: () => context.push(Routes.permission),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, SkyNavBar.reservedHeight),
                sliver: SliverList.list(children: [
                  _FeaturedCard(noradId: selected, now: now),
                  const SizedBox(height: 22),
                  Text('Upcoming visible passes', style: AppText.section),
                  const SizedBox(height: 10),
                  _PassList(noradId: selected, now: now),
                  const SizedBox(height: 22),
                  Text('Other satellites', style: AppText.section),
                  const SizedBox(height: 10),
                  for (final s in defaultSatellites.where((s) => s.noradId != selected)) ...[
                    _SatRow(satellite: s, now: now),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Positions and passes: N2YO.com · Orbit elements: CelesTrak',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured satellite
// ---------------------------------------------------------------------------

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.noradId, required this.now});

  final int noradId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sat = satelliteById(noradId);
    final track = ref.watch(satTrackProvider(noradId)).value;
    final elements = ref.watch(orbitElementsProvider(noradId)).value;
    final passes = ref.watch(satPassesProvider(noradId));
    final sample = track?.at(now);

    return GlassCard(
      accent: true,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          PulseRing(size: 22, child: const Icon(AppIcons.satellite, size: 20, color: AppColors.cyan)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sat.name, style: AppText.display(26)),
              Text(sat.kind, style: AppText.body(13, color: AppColors.textSoft)),
              const SizedBox(height: 2),
              Text('NORAD $noradId', style: AppText.mono(12, color: AppColors.textSoft)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        if (sample != null)
          _LiveStats(sample: sample)
        else if (track?.error != null || elements != null)
          _ElementStats(elements: elements)
        else
          const ShimmerBox(height: 76),
        if (track?.error != null && sample == null) ...[
          const SizedBox(height: 10),
          _ErrorNote(error: track!.error!),
        ],
        if (elements != null) ...[
          const SizedBox(height: 10),
          Text(
            'Inclination ${elements.inclinationDeg.toStringAsFixed(1)}° · '
            'period ${elements.periodMin.toStringAsFixed(1)} min',
            style: AppText.mono(12, color: AppColors.textSoft),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppColors.accentBorder),
        const SizedBox(height: 14),
        _NextPass(passes: passes, now: now),
        if (passes.value?.where((p) => p.end.isAfter(now)).firstOrNull case final next?) ...[
          const SizedBox(height: 14),
          PassArcView(pass: next, name: sat.name, live: sample, now: now),
        ],
      ]),
    );
  }
}

/// Altitude, speed, ground point and direction from a live N2YO sample.
class _LiveStats extends StatelessWidget {
  const _LiveStats({required this.sample});

  final SatSample sample;

  @override
  Widget build(BuildContext context) {
    final lat = sample.latDeg, lon = sample.lonDeg;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _Stat(label: 'Altitude', value: sample.altKm.toStringAsFixed(0), unit: 'km')),
        Expanded(child: _Stat(label: 'Speed', value: circularSpeedKmS(sample.altKm).toStringAsFixed(2), unit: 'km/s')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _Stat(
            label: 'Over',
            value: '${lat.abs().toStringAsFixed(1)}°${lat >= 0 ? 'N' : 'S'} '
                '${lon.abs().toStringAsFixed(1)}°${lon >= 0 ? 'E' : 'W'}',
            small: true,
          ),
        ),
        Expanded(
          child: _Stat(
            label: 'From you',
            value: sample.isUp
                ? '${sample.elDeg.toStringAsFixed(0)}° up, ${compass16(sample.azDeg)}'
                : 'Below horizon',
            small: true,
            highlight: sample.isUp,
          ),
        ),
      ]),
    ]);
  }
}

/// Fallback when there is no live position: values derived from CelesTrak elements.
class _ElementStats extends StatelessWidget {
  const _ElementStats({required this.elements});

  final OrbitElements? elements;

  @override
  Widget build(BuildContext context) {
    final e = elements;
    if (e == null) return const ShimmerBox(height: 60);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _Stat(label: 'Mean altitude', value: e.meanHeightKm.toStringAsFixed(0), unit: 'km')),
        Expanded(child: _Stat(label: 'Speed', value: circularSpeedKmS(e.meanHeightKm).toStringAsFixed(2), unit: 'km/s')),
      ]),
      const SizedBox(height: 6),
      Text('From orbit elements dated ${formatDay(e.epoch)}', style: AppText.caption),
    ]);
  }
}

class _NextPass extends StatelessWidget {
  const _NextPass({required this.passes, required this.now});

  final AsyncValue<List<SatPass>> passes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return passes.when(
      loading: () => const ShimmerBox(height: 54),
      error: (e, _) => Text(
        e is SatException ? _passErrorText(e) : 'Pass predictions are unavailable right now.',
        style: AppText.body(13, color: AppColors.textSoft),
      ),
      data: (list) {
        final next = list.where((p) => p.end.isAfter(now)).firstOrNull;
        if (next == null) {
          return Text('No visible passes in the next 5 days from here.',
              style: AppText.body(13, color: AppColors.textSoft));
        }
        final happening = !next.start.isAfter(now);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(happening ? 'Visible now' : 'Next visible pass', style: AppText.body(13, color: AppColors.textSoft)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            GradientText(formatClock(next.start), style: AppText.mono(28, weight: FontWeight.w500)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                happening ? 'until ${formatClock(next.end)}' : '${formatDay(next.start)} · ${formatRelative(next.start, now)}',
                style: AppText.body(13, color: AppColors.textSoft),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(next.pathText, style: AppText.body(14, weight: FontWeight.w600)),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pass list
// ---------------------------------------------------------------------------

class _PassList extends ConsumerWidget {
  const _PassList({required this.noradId, required this.now});

  final int noradId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passes = ref.watch(satPassesProvider(noradId));
    return passes.when(
      loading: () => const ShimmerList(count: 3, height: 64),
      error: (e, _) => GlassCard(
        child: Text(
          e is SatException ? _passErrorText(e) : 'Pass predictions are unavailable right now.',
          style: AppText.body(14, color: AppColors.textSoft),
        ),
      ),
      data: (list) {
        final upcoming = list.where((p) => p.end.isAfter(now)).toList();
        if (upcoming.isEmpty) {
          return const CosmoMessage(
            pose: CosmoPose.telescope,
            cosmoSize: 90,
            title: 'No visible passes',
            message: 'Nothing bright enough in a dark sky over the next 5 days. Try another satellite.',
          );
        }
        return Column(children: [
          for (final p in upcoming.take(6)) ...[
            _PassRow(pass: p, onTap: () => _showPassSheet(context, p, satelliteById(noradId).name, now)),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}

void _showPassSheet(BuildContext context, SatPass pass, String name, DateTime now) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.surfaceBorderStrong, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('$name · ${formatDay(pass.start)}', style: AppText.body(13, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            GradientText(formatClock(pass.start), style: AppText.mono(30, weight: FontWeight.w500)),
            const SizedBox(width: 10),
            Expanded(child: Text(pass.pathText, style: AppText.body(14, weight: FontWeight.w600))),
          ]),
          const SizedBox(height: 14),
          PassArcView(pass: pass, name: name, now: now),
        ]),
      ),
    ),
  );
}

class _PassRow extends StatelessWidget {
  const _PassRow({required this.pass, this.onTap});

  final SatPass pass;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mag = pass.mag;
    return GlassCard(
      onTap: onTap,
      semanticLabel: '${formatDay(pass.start)} at ${formatClock(pass.start)}. ${pass.pathText}'
          '${mag == null ? '' : '. Magnitude ${mag.toStringAsFixed(1)}'}',
      child: ExcludeSemantics(
        child: Row(children: [
          SizedBox(
            width: 74,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatClock(pass.start), style: AppText.mono(18, weight: FontWeight.w500)),
              Text(formatDay(pass.start), style: AppText.caption),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(pass.pathText, style: AppText.body(13, color: AppColors.textSoft, height: 1.35))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${pass.maxEl.round()}°', style: AppText.mono(16, color: AppColors.cyan)),
            Text(mag == null ? 'max' : 'mag ${mag.toStringAsFixed(1)}', style: AppText.caption),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Other satellites
// ---------------------------------------------------------------------------

class _SatRow extends ConsumerWidget {
  const _SatRow({required this.satellite, required this.now});

  final Satellite satellite;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = satellite.noradId;
    final sample = ref.watch(satTrackProvider(id)).value?.at(now);
    final elements = ref.watch(orbitElementsProvider(id)).value;
    final next = ref.watch(satPassesProvider(id)).value?.where((p) => p.end.isAfter(now)).firstOrNull;

    final altKm = sample?.altKm ?? elements?.meanHeightKm;
    final detail = [
      if (altKm != null) '${altKm.toStringAsFixed(0)} km',
      if (sample != null) sample.isUp ? '${sample.elDeg.round()}° up' : 'below horizon',
    ].join(' · ');

    return GlassCard(
      onTap: () => ref.read(selectedSatelliteProvider.notifier).select(id),
      semanticLabel: 'Show ${satellite.name}',
      child: ExcludeSemantics(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.violet.withValues(alpha: 0.4)),
            ),
            child: const Icon(AppIcons.satellite, size: 22, color: AppColors.violetSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(satellite.name, style: AppText.cardTitle, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('$id', style: AppText.mono(11, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 2),
              Text(
                detail.isEmpty ? satellite.kind : detail,
                style: AppText.mono(12, color: AppColors.textSoft),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Next pass', style: AppText.caption),
            Text(next == null ? '—' : formatClock(next.start), style: AppText.mono(15, color: AppColors.cyan)),
          ]),
          const SizedBox(width: 4),
          const Icon(AppIcons.chevronRight, size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

String _passErrorText(SatException e) => switch (e.kind) {
      SatErrorKind.noKey => 'Add N2YO_API_KEY to .env to load pass predictions.',
      SatErrorKind.blockedInBrowser => 'Pass predictions need the Android or iOS app — browsers block N2YO.',
      SatErrorKind.offline => 'No internet connection. Passes will load when you are back online.',
      SatErrorKind.api => 'N2YO could not answer (${e.message ?? 'unknown error'}). Try again later.',
    };

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error});

  final SatException error;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (error.kind) {
      SatErrorKind.noKey => (AppIcons.keyRound, 'No N2YO key, so no live position. Add N2YO_API_KEY to .env.'),
      SatErrorKind.blockedInBrowser => (AppIcons.globe, 'Live position needs the Android or iOS app — browsers block N2YO.'),
      SatErrorKind.offline => (AppIcons.wifiOff, 'Offline. Showing orbit data until the connection returns.'),
      SatErrorKind.api => (AppIcons.cloudOff, 'N2YO error: ${error.message ?? 'unknown'}. Showing orbit data.'),
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.warm),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: AppText.body(12, color: AppColors.textSoft, height: 1.35))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.unit, this.small = false, this.highlight = false});

  final String label;
  final String value;
  final String? unit;
  final bool small;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final style = AppText.mono(small ? 15 : 26, weight: FontWeight.w500);
    return Semantics(
      label: '$label ${value.replaceAll('°', ' degrees ')} ${unit ?? ''}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.body(12, color: AppColors.textSoft)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: highlight
                ? GradientText(value, style: style)
                : Text(value, style: style, overflow: TextOverflow.ellipsis),
          ),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(unit!, style: AppText.body(12, color: AppColors.textSoft)),
          ],
        ]),
      ]),
    );
  }
}

/// Dashed arc across the hero with a satellite travelling along it (10 s loop).
class _OrbitArc extends StatelessWidget {
  const _OrbitArc();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: TimeBuilder(
          restSeconds: 4,
          builder: (_, s, _) => CustomPaint(painter: _OrbitPainter(loop01(s, 10))),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);

  /// Position along the arc, 0…1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // A wide ellipse whose upper part crosses the hero, like an orbit seen edge-on.
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.55, size.height * 1.05),
      width: size.width * 1.5,
      height: size.height * 1.3,
    );
    const start = math.pi * 1.08, sweep = math.pi * 0.84;

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.cyan.withValues(alpha: 0.45);
    const segments = 70;
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(rect, start + sweep * i / segments, sweep / segments, false, dash);
    }

    final a = start + sweep * t;
    final p = Offset(rect.center.dx + rect.width / 2 * math.cos(a), rect.center.dy + rect.height / 2 * math.sin(a));
    // Fade in and out at the ends of the arc.
    final fade = math.sin(math.pi * t).clamp(0.0, 1.0);
    canvas.drawCircle(p, 10, Paint()..color = AppColors.cyan.withValues(alpha: 0.25 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(p, 3.5, Paint()..color = AppColors.text.withValues(alpha: fade));
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.cyan.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}
