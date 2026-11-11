import 'dart:math' as math;

import 'angles.dart';
import 'coords.dart';
import 'models.dart';
import 'planets.dart';
import 'rise_set.dart';
import 'sky_position.dart';

/// Pure-Dart geometry behind the animated sky views: where an object travels
/// across the sky tonight, the arc of a satellite pass, the sky-dome
/// projection, and the solar-system layout. No Flutter imports.

/// One point on a path across the sky.
class SkyPoint {
  const SkyPoint(this.time, this.altDeg, this.azDeg);

  final DateTime time;
  final double altDeg;
  final double azDeg;

  bool get isUp => altDeg > 0;
}

/// The object's path across the sky tonight, sampled every [step].
///
/// * Normal objects: from rise to set of the transit nearest solar midnight.
/// * Circumpolar: the full 24 h loop around the pole.
/// * Never rises: an empty list.
List<SkyPoint> skyTrackTonight(
  PositionFn position,
  Observer observer,
  RiseTransitSet rts, {
  Duration step = const Duration(minutes: 5),
}) {
  final DateTime start, end;
  switch (rts.kind) {
    case RiseSetKind.normal:
      start = rts.rise!;
      end = rts.set!;
    case RiseSetKind.circumpolar:
      start = rts.transit.subtract(const Duration(hours: 12));
      end = rts.transit.add(const Duration(hours: 12));
    case RiseSetKind.neverRises:
      return const [];
  }
  final out = <SkyPoint>[];
  for (var t = start; !t.isAfter(end); t = t.add(step)) {
    final h = horizontalAt(position(t), observer, t, refraction: true);
    out.add(SkyPoint(t, h.altDeg, h.azDeg));
  }
  final last = horizontalAt(position(end), observer, end, refraction: true);
  if (out.isEmpty || out.last.time != end) out.add(SkyPoint(end, last.altDeg, last.azDeg));
  return out;
}

/// The point on [track] nearest to [t] (linear interpolation between samples).
SkyPoint? trackPointAt(List<SkyPoint> track, DateTime t) {
  if (track.isEmpty) return null;
  if (!t.isAfter(track.first.time)) return track.first;
  if (!t.isBefore(track.last.time)) return track.last;
  for (var i = 0; i < track.length - 1; i++) {
    final a = track[i], b = track[i + 1];
    if (!t.isBefore(a.time) && t.isBefore(b.time)) {
      final span = b.time.difference(a.time).inMicroseconds;
      final f = span == 0 ? 0.0 : t.difference(a.time).inMicroseconds / span;
      return SkyPoint(t, a.altDeg + (b.altDeg - a.altDeg) * f, a.azDeg + norm180(b.azDeg - a.azDeg) * f);
    }
  }
  return track.last;
}

/// Index into [track] for a fraction 0…1 of its duration, interpolated.
SkyPoint trackPointAtFraction(List<SkyPoint> track, double fraction) {
  final f = fraction.clamp(0.0, 1.0);
  final start = track.first.time, end = track.last.time;
  final t = start.add(Duration(microseconds: (end.difference(start).inMicroseconds * f).round()));
  return trackPointAt(track, t)!;
}

// ---------------------------------------------------------------------------
// Satellite pass arc
// ---------------------------------------------------------------------------

/// Unit vector for a direction in the sky (x east, y north, z up).
({double x, double y, double z}) _unit(double altDeg, double azDeg) =>
    (x: cosD(altDeg) * sinD(azDeg), y: cosD(altDeg) * cosD(azDeg), z: sinD(altDeg));

/// Spherical linear interpolation between two directions.
({double altDeg, double azDeg}) _slerp(({double x, double y, double z}) a, ({double x, double y, double z}) b, double t) {
  final dot = (a.x * b.x + a.y * b.y + a.z * b.z).clamp(-1.0, 1.0);
  final omega = math.acos(dot);
  double wa, wb;
  if (omega < 1e-6) {
    wa = 1 - t;
    wb = t;
  } else {
    wa = math.sin((1 - t) * omega) / math.sin(omega);
    wb = math.sin(t * omega) / math.sin(omega);
  }
  final x = wa * a.x + wb * b.x, y = wa * a.y + wb * b.y, z = wa * a.z + wb * b.z;
  final len = math.sqrt(x * x + y * y + z * z);
  return (altDeg: asinD(z / len), azDeg: norm360(atan2D(x, y)));
}

/// A satellite pass as a smooth arc through its start, highest and end points.
///
/// N2YO gives only those three points. A pass is close to a great circle on
/// the sky, so two spherical interpolations through the highest point draw it
/// faithfully. Times are interpolated linearly within each half.
List<SkyPoint> passArc({
  required DateTime start,
  required double startAltDeg,
  required double startAzDeg,
  required DateTime max,
  required double maxAltDeg,
  required double maxAzDeg,
  required DateTime end,
  required double endAltDeg,
  required double endAzDeg,
  int segments = 48,
}) {
  final a = _unit(startAltDeg, startAzDeg), m = _unit(maxAltDeg, maxAzDeg), b = _unit(endAltDeg, endAzDeg);
  final out = <SkyPoint>[];
  final half = segments ~/ 2;
  for (var i = 0; i <= segments; i++) {
    final firstHalf = i <= half;
    final f = firstHalf ? i / half : (i - half) / (segments - half);
    final p = firstHalf ? _slerp(a, m, f) : _slerp(m, b, f);
    final t0 = firstHalf ? start : max, t1 = firstHalf ? max : end;
    final t = t0.add(Duration(microseconds: (t1.difference(t0).inMicroseconds * f).round()));
    out.add(SkyPoint(t, p.altDeg, p.azDeg));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Sky-dome projection
// ---------------------------------------------------------------------------

/// Maps a sky direction to the unit disc of the dome: the zenith at the
/// centre, the horizon on the rim, north up and east to the right (the way a
/// compass in your hand reads). Returns (x right, y down) in −1…1 for points
/// above the horizon; below it the radius grows past 1.
///
/// [headingDeg] rotates the dome so that the direction the phone faces is at
/// the top (used by the live pointer).
({double x, double y}) domeXy(double altDeg, double azDeg, {double headingDeg = 0}) {
  final r = (90 - altDeg) / 90;
  final a = azDeg - headingDeg;
  return (x: r * sinD(a), y: -r * cosD(a));
}

/// Plain-language size of an angle, using the astronomer's rule of thumb
/// that a fist at arm's length covers about 10°.
String fistsText(double altDeg) {
  if (altDeg >= 80) return 'almost straight overhead';
  final fists = (altDeg / 10).round();
  if (fists <= 0) return 'right on the horizon';
  if (fists == 1) return 'about one fist above the horizon';
  return 'about $fists fists above the horizon';
}

// ---------------------------------------------------------------------------
// Solar system
// ---------------------------------------------------------------------------

/// Position of a planet (or Earth) in the solar-system diagram, with the
/// elongation that decides when it is visible.
class PlanetView {
  const PlanetView({required this.planet, required this.x, required this.y, required this.elongationDeg});

  /// Null for Earth.
  final Planet? planet;

  /// Heliocentric ecliptic coordinates, AU.
  final double x;
  final double y;

  /// Angle Sun–Earth–planet, −180…180: positive east of the Sun (evening sky),
  /// negative west (morning sky). Zero for Earth itself.
  final double elongationDeg;

  bool get eveningSky => elongationDeg > 0;

  double get distanceFromSunAu => math.sqrt(x * x + y * y);
}

/// Mercury–Saturn plus Earth at [t]. Uranus and Neptune are left out: they
/// would push the inner planets into a dot.
List<PlanetView> solarSystemAt(DateTime t) {
  final e = earthHeliocentricXy(t);
  final sunDirX = -e.x, sunDirY = -e.y; // Earth → Sun
  PlanetView view(Planet p) {
    final h = heliocentricXy(p, t);
    final vx = h.x - e.x, vy = h.y - e.y; // Earth → planet
    final dot = vx * sunDirX + vy * sunDirY;
    final cross = sunDirX * vy - sunDirY * vx;
    final elong = atan2D(cross, dot);
    return PlanetView(planet: p, x: h.x, y: h.y, elongationDeg: elong);
  }

  return [
    PlanetView(planet: null, x: e.x, y: e.y, elongationDeg: 0),
    for (final p in const [Planet.mercury, Planet.venus, Planet.mars, Planet.jupiter, Planet.saturn]) view(p),
  ];
}

/// One sentence on what the elongation means for an observer.
String elongationText(String name, double elongationDeg) {
  final e = elongationDeg.abs();
  final side = elongationDeg > 0 ? 'east' : 'west';
  if (e < 10) return '$name is almost in line with the Sun (${e.round()}°), so it is lost in daylight right now.';
  if (e < 50) {
    return elongationDeg > 0
        ? '$name is ${e.round()}° east of the Sun, so look for it low in the west after sunset.'
        : '$name is ${e.round()}° west of the Sun, so look for it low in the east before sunrise.';
  }
  if (e < 140) {
    return elongationDeg > 0
        ? '$name is ${e.round()}° east of the Sun: well up in the evening sky, setting after midnight.'
        : '$name is ${e.round()}° west of the Sun: rises after midnight and is high before dawn.';
  }
  return '$name is ${e.round()}° from the Sun, nearly opposite it ($side side): up almost all night and at its brightest.';
}

/// Planet enum → catalog id used by [SolarSystemIds].
String planetId(Planet p) => p.name;

/// Catalog id → planet, or null for anything else.
Planet? planetFromId(String id) => SolarSystemIds.planets[id];
