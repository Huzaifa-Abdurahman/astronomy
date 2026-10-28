import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../astro/coords.dart';
import '../astro/models.dart';
import '../astro/rise_set.dart';
import '../astro/sky_position.dart';
import '../astro/sun.dart';
import 'catalog_repository.dart';
import 'clock.dart';
import 'location_service.dart';
import 'settings.dart';

/// Glue between the pure `lib/astro` engine and the UI: location + clock +
/// catalog in, live positions and tonight's timings out. Every value is
/// computed on the device; nothing here calls a network service.

/// RA/Dec function for an object at the current location, honouring the
/// precession setting.
final positionFnProvider = Provider.family<PositionFn?, String>((ref, id) {
  final object = ref.watch(skyObjectProvider(id));
  final observer = ref.watch(observerProvider);
  if (object == null || observer == null) return null;
  final precess = ref.watch(settingsProvider.select((s) => s.precession));
  return positionFnFor(object, observer, precess: precess);
});

/// Tonight's sunset / darkness / sunrise. Only recomputed when the night or
/// the place changes, not on every clock tick.
final nightProvider = Provider<NightInfo?>((ref) {
  final observer = ref.watch(observerProvider);
  if (observer == null) return null;
  // Bucket "now" by hour: nightFor only changes at its 6 h rollover anyway.
  final hour = ref.watch(nowProvider.select((t) => t.millisecondsSinceEpoch ~/ 3600000));
  return nightFor(observer, DateTime.fromMillisecondsSinceEpoch(hour * 3600000, isUtc: true));
});

/// Live state of one object right now.
class LiveSky {
  const LiveSky({required this.equatorial, required this.horizontal, required this.at});

  final Equatorial equatorial;

  /// Apparent position (with refraction), for display and pointing.
  final HorizontalPosition horizontal;
  final DateTime at;
}

/// Alt/Az now, refreshed every 10 s.
final liveSkyProvider = Provider.family<LiveSky?, String>((ref, id) {
  final fn = ref.watch(positionFnProvider(id));
  final observer = ref.watch(observerProvider);
  if (fn == null || observer == null) return null;
  final now = ref.watch(nowProvider);
  final eq = fn(now);
  return LiveSky(equatorial: eq, horizontal: horizontalAt(eq, observer, now, refraction: true), at: now);
});

/// Rise/peak/set, the best dark window and the altitude curve for tonight.
class ObjectTonight {
  const ObjectTonight({required this.rts, required this.night, required this.window, required this.curve});

  final RiseTransitSet rts;
  final NightInfo night;

  /// Sun below −18° and object above 20°; null if that never happens tonight.
  final VisibilityWindow? window;

  /// Altitude from about noon to 08:00 the next morning.
  final List<AltitudeSample> curve;

  bool get visibleTonight => curve.any((s) => s.altDeg > 0 && _isDark(s.time)) || window != null;

  bool _isDark(DateTime t) {
    final dark = night.dark;
    return dark != null && !t.isBefore(dark.start) && !t.isAfter(dark.end);
  }
}

final objectTonightProvider = Provider.family<ObjectTonight?, String>((ref, id) {
  final fn = ref.watch(positionFnProvider(id));
  final observer = ref.watch(observerProvider);
  final night = ref.watch(nightProvider);
  final object = ref.watch(skyObjectProvider(id));
  if (fn == null || observer == null || night == null || object == null) return null;

  final mid = night.solarMidnight;
  final h0 = object.id == SolarSystemIds.sun ? h0Sun : h0Star;
  final rts = riseTransitSet(fn, observer, mid, h0Deg: h0);
  final dark = night.dark;
  // Start on a whole hour near local noon so the chart's axis labels are round.
  final noon = mid.subtract(const Duration(hours: 12));
  final start = DateTime.utc(noon.year, noon.month, noon.day, noon.hour);
  return ObjectTonight(
    rts: rts,
    night: night,
    window: dark == null ? null : bestViewingWindow(fn, observer, dark),
    curve: altitudeSeries(fn, observer, start, start.add(const Duration(hours: 20))),
  );
});

/// A row in Explore: an object with its position right now.
class SkyListItem {
  const SkyListItem({
    required this.object,
    required this.equatorial,
    required this.horizontal,
    required this.kind,
    this.nextRise,
  });

  final SkyObject object;

  /// RA/Dec now (moves for the Moon and planets).
  final Equatorial equatorial;
  final HorizontalPosition horizontal;
  final RiseSetKind kind;

  /// Next rise when currently below the horizon.
  final DateTime? nextRise;
}

/// Every catalog object with its live position (Explore list, Home search).
final skyListProvider = Provider<List<SkyListItem>?>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  final observer = ref.watch(observerProvider);
  if (catalog == null || observer == null) return null;
  final now = ref.watch(nowProvider);
  final precess = ref.watch(settingsProvider.select((s) => s.precession));
  return [
    for (final o in catalog)
      () {
        final fn = positionFnFor(o, observer, precess: precess);
        final eq = fn(now);
        final h = horizontalAt(eq, observer, now, refraction: true);
        DateTime? nextRise;
        var kind = RiseSetKind.normal;
        if (!h.isUp) {
          final rts = riseTransitSet(fn, observer, now);
          kind = rts.kind;
          final rise = rts.rise;
          if (rise != null) {
            // The nearest transit's rise may be in the past; then it is ~1 day later.
            nextRise = rise.isAfter(now) ? rise : riseTransitSet(fn, observer, now.add(const Duration(hours: 24))).rise;
          }
        }
        return SkyListItem(object: o, equatorial: eq, horizontal: h, kind: kind, nextRise: nextRise);
      }(),
  ];
});

/// Tonight's highlight on Home: the most rewarding well-known object now.
///
/// Candidates are named deep-sky objects of magnitude ≤ 6 and the naked-eye
/// planets (Uranus and Neptune need optics, so they are left out).
/// When it is dark and something is above 20°, the score is the current
/// altitude minus 4 × magnitude (planets count as magnitude 0). In daylight,
/// or when nothing is high yet, the peak altitude of tonight's best window is
/// used instead, so the card still shows what to look forward to.
const _notHighlightPlanets = {SolarSystemIds.moon, 'uranus', 'neptune'};

final highlightProvider = Provider<String?>((ref) {
  final list = ref.watch(skyListProvider);
  final observer = ref.watch(observerProvider);
  final night = ref.watch(nightProvider);
  if (list == null || observer == null || night == null) return null;
  final now = ref.watch(nowProvider);
  final precess = ref.watch(settingsProvider.select((s) => s.precession));

  bool isCandidate(SkyObject o) {
    if (o.type == SkyObjectType.planet) return !_notHighlightPlanets.contains(o.id);
    if (o.type == SkyObjectType.star) return false;
    return !o.name.startsWith('Messier') && (o.mag ?? 99) <= 6;
  }

  double magOf(SkyObject o) => o.type == SkyObjectType.planet ? 0 : o.mag!;

  final darkNow = night.dark != null && !now.isBefore(night.dark!.start) && !now.isAfter(night.dark!.end);
  String? bestId;
  var bestScore = double.negativeInfinity;
  if (darkNow) {
    for (final item in list.where((i) => isCandidate(i.object) && i.horizontal.altDeg > minViewingAltDeg)) {
      final score = item.horizontal.altDeg - 4 * magOf(item.object);
      if (score > bestScore) (bestScore, bestId) = (score, item.object.id);
    }
  }
  if (bestId == null && night.dark != null) {
    for (final item in list.where((i) => isCandidate(i.object))) {
      final w = bestViewingWindow(positionFnFor(item.object, observer, precess: precess), observer, night.dark!);
      if (w == null) continue;
      final score = w.peakAltDeg - 4 * magOf(item.object);
      if (score > bestScore) (bestScore, bestId) = (score, item.object.id);
    }
  }
  return bestId;
});
