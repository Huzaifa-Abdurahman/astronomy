import 'dart:math' as math;

/// Small orbit helpers for Earth satellites. Pure Dart, no Flutter imports.
///
/// The satellite positions themselves come from N2YO (they run SGP4 on the
/// latest TLEs); these helpers only derive display values from published
/// orbital elements and interpolate between API samples.

/// Earth's gravitational parameter μ = GM, km³/s² (WGS-84).
const double earthMuKm3s2 = 398600.4418;

/// Earth's equatorial radius, km (WGS-84).
const double earthRadiusKm = 6378.137;

/// Semi-major axis from mean motion, by Kepler's third law:
///
///     n = 2π · revsPerDay / 86400        (rad/s)
///     a = (μ / n²)^(1/3)                 (km)
///
/// Source: Vallado, *Fundamentals of Astrodynamics and Applications*, §2.2.
double semiMajorAxisKm(double meanMotionRevPerDay) {
  final n = 2 * math.pi * meanMotionRevPerDay / 86400;
  return math.pow(earthMuKm3s2 / (n * n), 1 / 3).toDouble();
}

/// Orbital period in minutes: one day divided by revolutions per day.
double periodMinutes(double meanMotionRevPerDay) => 1440 / meanMotionRevPerDay;

/// Perigee and apogee heights above the equator, km: a(1 ∓ e) − R⊕.
({double perigeeKm, double apogeeKm}) apsisHeightsKm(double meanMotionRevPerDay, double eccentricity) {
  final a = semiMajorAxisKm(meanMotionRevPerDay);
  return (perigeeKm: a * (1 - eccentricity) - earthRadiusKm, apogeeKm: a * (1 + eccentricity) - earthRadiusKm);
}

/// Orbital speed at a given height for a near-circular orbit, km/s:
///
///     v = √(μ / (R⊕ + h))
///
/// This is the vis-viva equation with r = a. All default satellites have
/// e < 0.001, so the error is well under 0.1 %.
double circularSpeedKmS(double heightKm) => math.sqrt(earthMuKm3s2 / (earthRadiusKm + heightKm));

/// One sampled satellite position (one element of N2YO `positions`).
class SatSample {
  const SatSample({
    required this.time,
    required this.latDeg,
    required this.lonDeg,
    required this.altKm,
    required this.azDeg,
    required this.elDeg,
  });

  final DateTime time;

  /// Sub-satellite point on the ground.
  final double latDeg;
  final double lonDeg;

  /// Height above the ellipsoid, km.
  final double altKm;

  /// Direction from the observer: azimuth (from north, clockwise) and elevation.
  final double azDeg;
  final double elDeg;

  bool get isUp => elDeg > 0;
}

/// Linear interpolation between [a] and [b] at fraction [t] (0…1), taking the
/// short way round for angles that wrap at ±180° (longitude) or 0/360° (azimuth).
SatSample lerpSample(SatSample a, SatSample b, double t, DateTime at) {
  double lerp(double x, double y) => x + (y - x) * t;
  double lerpWrap(double x, double y) {
    var d = (y - x) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return x + d * t;
  }

  double norm180(double x) => ((x + 180) % 360 + 360) % 360 - 180;
  double norm360(double x) => (x % 360 + 360) % 360;

  return SatSample(
    time: at,
    latDeg: lerp(a.latDeg, b.latDeg),
    lonDeg: norm180(lerpWrap(a.lonDeg, b.lonDeg)),
    altKm: lerp(a.altKm, b.altKm),
    azDeg: norm360(lerpWrap(a.azDeg, b.azDeg)),
    elDeg: lerp(a.elDeg, b.elDeg),
  );
}

/// Position at [at] from a time-ordered list of samples. N2YO returns one
/// sample per second, so interpolating gives smooth movement between polls
/// (CLAUDE.md §9). Outside the sampled range the nearest end is returned.
SatSample? sampleAt(List<SatSample> samples, DateTime at) {
  if (samples.isEmpty) return null;
  if (!at.isAfter(samples.first.time)) return samples.first;
  if (!at.isBefore(samples.last.time)) return samples.last;
  for (var i = 0; i < samples.length - 1; i++) {
    final a = samples[i], b = samples[i + 1];
    if (!at.isBefore(a.time) && at.isBefore(b.time)) {
      final span = b.time.difference(a.time).inMicroseconds;
      final t = span == 0 ? 0.0 : at.difference(a.time).inMicroseconds / span;
      return lerpSample(a, b, t, at);
    }
  }
  return samples.last;
}
