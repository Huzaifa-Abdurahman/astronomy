import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../astro/angles.dart';
import '../../astro/coords.dart';
import '../../astro/models.dart';
import '../../astro/sky_track.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/sky_dome.dart';
import '../../data/catalog_repository.dart';
import '../../data/clock.dart';
import '../../data/location_service.dart';
import '../../data/sky_providers.dart';

/// Everything the guide needs, computed once per clock tick.
class FindItData {
  const FindItData({
    required this.name,
    required this.now,
    required this.live,
    required this.tonight,
    required this.track,
    required this.target,
    required this.targetTime,
  });

  final String name;
  final DateTime now;
  final HorizontalPosition live;
  final ObjectTonight tonight;
  final List<SkyPoint> track;

  /// Where to look: the live position when the object is up, otherwise its
  /// best moment tonight.
  final HorizontalPosition target;

  /// Null when [target] is the live position.
  final DateTime? targetTime;

  bool get upNow => targetTime == null;
}

final findItDataProvider = Provider.family<FindItData?, String>((ref, id) {
  final object = ref.watch(skyObjectProvider(id));
  final fn = ref.watch(positionFnProvider(id));
  final observer = ref.watch(observerProvider);
  final tonight = ref.watch(objectTonightProvider(id));
  final live = ref.watch(liveSkyProvider(id));
  if (object == null || fn == null || observer == null || tonight == null || live == null) return null;
  final now = ref.watch(nowProvider);
  final track = skyTrackTonight(fn, observer, tonight.rts);
  if (live.horizontal.isUp) {
    return FindItData(
      name: object.name,
      now: now,
      live: live.horizontal,
      tonight: tonight,
      track: track,
      target: live.horizontal,
      targetTime: null,
    );
  }
  final best = tonight.window?.peak ?? tonight.rts.transit;
  return FindItData(
    name: object.name,
    now: now,
    live: live.horizontal,
    tonight: tonight,
    track: track,
    target: horizontalAt(fn(best), observer, best, refraction: true),
    targetTime: best,
  );
});

/// Animated four-step guide: face the right way, look up, tonight's path,
/// best time. Auto-plays and loops; tap a step to jump to it.
class FindItGuide extends ConsumerWidget {
  const FindItGuide({super.key, required this.objectId});

  final String objectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(findItDataProvider(objectId));
    if (data == null) return const SizedBox.shrink();
    if (data.tonight.rts.kind == RiseSetKind.neverRises) {
      return GlassCard(
        child: Row(children: [
          const Icon(AppIcons.eyeOff, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${data.name} never rises above your horizon from this latitude.',
                style: AppText.body(14, color: AppColors.textSoft)),
          ),
        ]),
      );
    }
    return _Guide(data: data);
  }
}

enum _Step { face, lookUp, path, best }

class _Guide extends StatefulWidget {
  const _Guide({required this.data});

  final FindItData data;

  @override
  State<_Guide> createState() => _GuideState();
}

class _GuideState extends State<_Guide> with SingleTickerProviderStateMixin {
  static const _durations = {
    _Step.face: Duration(milliseconds: 1600),
    _Step.lookUp: Duration(milliseconds: 1800),
    _Step.path: Duration(milliseconds: 3200),
    _Step.best: Duration(milliseconds: 1800),
  };
  static const _hold = Duration(milliseconds: 1400);

  late final AnimationController _c = AnimationController(vsync: this, duration: _durations[_Step.face]);
  _Step _step = _Step.face;
  bool _playing = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _playing && !_reduced) {
        Future.delayed(_hold, () {
          if (mounted && _playing) _go(_Step.values[(_step.index + 1) % _Step.values.length]);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = reduceMotionOf(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      _playing = !reduced;
    }
    _start();
  }

  void _start() {
    _c.duration = _durations[_step];
    if (_reduced) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  void _go(_Step s) {
    setState(() => _step = s);
    _start();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing && _c.isCompleted) _go(_Step.values[(_step.index + 1) % _Step.values.length]);
    if (_playing && !_c.isAnimating && !_c.isCompleted) _c.forward();
    if (!_playing) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GlassCard(
      strongBorder: true,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(AppIcons.compass, size: 20, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(child: Text('How to find it', style: AppText.cardTitle)),
          if (!_reduced)
            IconButton(
              tooltip: _playing ? 'Pause' : 'Play',
              onPressed: _togglePlay,
              icon: Icon(_playing ? AppIcons.pause : AppIcons.play, size: 20, color: AppColors.textSoft),
            ),
        ]),
        const SizedBox(height: 4),
        TimeBuilder(
          restSeconds: 0.5,
          builder: (context, seconds, _) => AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _dome(d, Curves.easeInOutCubic.transform(_c.value), seconds),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (final s in _Step.values) ...[
            Expanded(child: _StepChip(step: s, active: s == _step, onTap: () => _go(s))),
            if (s != _Step.best) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _Caption(key: ValueKey(_step), step: _step, data: d),
        ),
      ]),
    );
  }

  Widget _dome(FindItData d, double p, double seconds) {
    final t = d.target;
    final dark = d.tonight.night.dark;
    final peak = d.tonight.window?.peak ?? d.tonight.rts.transit;
    final peakAlt = d.tonight.window?.peakAltDeg ?? d.tonight.rts.transitAltDeg;
    final normal = d.tonight.rts.kind == RiseSetKind.normal;

    final markers = <DomeMarker>[
      // Live position whenever the object is above the horizon.
      if (d.live.isUp && _step != _Step.lookUp)
        DomeMarker(altDeg: d.live.altDeg, azDeg: d.live.azDeg, pulse: true, label: 'now'),
    ];
    final tracks = <DomeTrack>[];
    double? arrowAz;
    var arrowProgress = 1.0;
    double? gaugeAlt;
    var gaugeProgress = 1.0;

    switch (_step) {
      case _Step.face:
        arrowAz = t.azDeg;
        arrowProgress = p;
        if (!d.upNow) markers.add(DomeMarker(altDeg: t.altDeg, azDeg: t.azDeg, color: AppColors.violetSoft, size: 5));
      case _Step.lookUp:
        arrowAz = t.azDeg;
        gaugeAlt = t.altDeg;
        gaugeProgress = p;
        markers.add(DomeMarker(altDeg: t.altDeg * p, azDeg: t.azDeg, pulse: p >= 1, label: p >= 1 ? '${t.altDeg.round()}°' : null));
      case _Step.path:
        tracks.add(DomeTrack(points: d.track, progress: p));
        if (d.track.length > 1) {
          final head = trackPointAtFraction(d.track, p);
          if (head.isUp) markers.add(DomeMarker(altDeg: head.altDeg, azDeg: head.azDeg, color: AppColors.text, size: 5, label: formatClock(head.time)));
        }
        if (normal && p > 0.02) markers.add(DomeMarker(altDeg: 0, azDeg: d.tonight.rts.riseAzDeg!, color: AppColors.warm, size: 4, label: 'rises'));
        if (normal && p >= 1) markers.add(DomeMarker(altDeg: 0, azDeg: d.tonight.rts.setAzDeg!, color: AppColors.warm, size: 4, label: 'sets'));
      case _Step.best:
        tracks.add(DomeTrack(points: d.track, highlight: dark, color: AppColors.cyan));
        final peakPoint = trackPointAt(d.track, peak);
        if (peakPoint != null) {
          markers.add(DomeMarker(
            altDeg: peakPoint.altDeg,
            azDeg: peakPoint.azDeg,
            star: true,
            size: 5 + 3 * p,
            color: AppColors.warm,
            label: p >= 1 ? '${formatClock(peak)} · ${peakAlt.round()}°' : null,
          ));
        }
    }

    return SkyDome(
      tracks: tracks,
      markers: markers,
      arrowAzDeg: arrowAz,
      arrowProgress: arrowProgress,
      gaugeAltDeg: gaugeAlt,
      gaugeProgress: gaugeProgress,
      seconds: seconds,
      semanticLabel: 'Sky map. ${_Caption.text(_step, d).$1}. ${_Caption.text(_step, d).$2}',
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, required this.active, required this.onTap});

  final _Step step;
  final bool active;
  final VoidCallback onTap;

  static const _labels = {_Step.face: 'Face', _Step.lookUp: 'Look up', _Step.path: 'Path', _Step.best: 'Best time'};

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Step ${step.index + 1}: ${_labels[step]}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? AppColors.cyan.withValues(alpha: 0.16) : AppColors.glassChip,
            border: Border.all(color: active ? AppColors.cyan : AppColors.glassChipBorder),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${step.index + 1}', style: AppText.mono(11, color: active ? AppColors.cyan : AppColors.textMuted)),
            Text(_labels[step]!, style: AppText.body(11, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({super.key, required this.step, required this.data});

  final _Step step;
  final FindItData data;

  /// (headline, detail) for a step.
  static (String, String) text(_Step step, FindItData d) {
    final t = d.target;
    final when = d.upNow ? 'Right now' : 'At ${formatClock(d.targetTime)}';
    final rts = d.tonight.rts;
    final dark = d.tonight.night.dark;
    final window = d.tonight.window;
    final peak = window?.peak ?? rts.transit;
    final peakAlt = window?.peakAltDeg ?? rts.transitAltDeg;
    switch (step) {
      case _Step.face:
        return ('Face ${compass16(t.azDeg)}', '$when, turn until ${_compassName(t.azDeg)} (${t.azDeg.round()}°) is straight ahead of you.');
      case _Step.lookUp:
        return ('Look up ${t.altDeg.round()}°', 'Hold a fist at arm\'s length: it spans about 10°. ${d.name} is ${fistsText(t.altDeg)}.');
      case _Step.path:
        switch (rts.kind) {
          case RiseSetKind.normal:
            return (
              'Tonight\'s path',
              'Rises ${formatClock(rts.rise)} in the ${compass16(rts.riseAzDeg!)}, climbs to ${rts.transitAltDeg.round()}° '
                  'due ${rts.transitAzDeg == 180 ? 'south' : 'north'} at ${formatClock(rts.transit)}, sets ${formatClock(rts.set)} in the ${compass16(rts.setAzDeg!)}.'
            );
          case RiseSetKind.circumpolar:
            final lowest = d.track.isEmpty ? 0.0 : d.track.map((p) => p.altDeg).reduce((a, b) => a < b ? a : b);
            return ('Circles the pole', '${d.name} never sets from here. Highest (${rts.transitAltDeg.round()}°) at ${formatClock(rts.transit)}, lowest (${lowest.round()}°) twelve hours later.');
          case RiseSetKind.neverRises:
            return ('Not visible', 'Never rises from this latitude.');
        }
      case _Step.best:
        if (window != null) {
          return (
            'Best ${formatClock(window.start)}–${formatClock(window.end)}',
            'Sky fully dark and ${d.name} above 20°. Highest at ${formatClock(peak)} (${peakAlt.round()}°). The bright part of the path is the dark-sky window.'
          );
        }
        if (dark == null) {
          return ('No full darkness tonight', 'The Sun never gets 18° below the horizon at your latitude tonight. Try around ${formatClock(rts.transit)}, when it is highest.');
        }
        return ('Low tonight', '${d.name} stays below 20° while the sky is dark. It is highest at ${formatClock(rts.transit)} (${rts.transitAltDeg.round()}°).');
    }
  }

  static String _compassName(double az) {
    const names = {
      'N': 'north', 'NNE': 'north-north-east', 'NE': 'north-east', 'ENE': 'east-north-east',
      'E': 'east', 'ESE': 'east-south-east', 'SE': 'south-east', 'SSE': 'south-south-east',
      'S': 'south', 'SSW': 'south-south-west', 'SW': 'south-west', 'WSW': 'west-south-west',
      'W': 'west', 'WNW': 'west-north-west', 'NW': 'north-west', 'NNW': 'north-north-west',
    };
    return names[compass16(az)] ?? compass16(az);
  }

  @override
  Widget build(BuildContext context) {
    final (head, detail) = text(step, data);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GradientText(head, style: AppText.display(24, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(detail, style: AppText.body(13, color: AppColors.textSoft, height: 1.4)),
    ]);
  }
}
