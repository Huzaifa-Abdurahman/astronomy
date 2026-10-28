/// Rise, transit and set times, visibility windows and altitude curves.
library;

import 'dart:math' as math;

import 'angles.dart';
import 'coords.dart';
import 'models.dart';
import 'time.dart';

/// Gives a body's RA/Dec at an instant. Fixed stars return a constant; the
/// Sun, Moon and planets compute it (see `sun.dart`, `planets.dart`).
typedef PositionFn = Equatorial Function(DateTime utc);

/// Standard altitude h0 for stars and deep-sky objects: −34′ refraction (CLAUDE.md §6.6).
const double h0Star = -0.5667;

/// Standard altitude for the Sun's upper limb at sunrise/sunset.
const double h0Sun = -0.833;

/// Sun altitude at the start/end of astronomical darkness.
const double h0AstronomicalTwilight = -18;

/// Minimum altitude for comfortable viewing used by the best-window search.
const double minViewingAltDeg = 20;

/// Semi-diurnal arc (CLAUDE.md §6.6):
/// `cos H0 = (sin h0 − sin φ · sin δ) / (cos φ · cos δ)`.
///
/// Returns the raw cos H0: < −1 means circumpolar, > 1 means never rises.
/// Source: Meeus ch. 15, eq. 15.1.
double cosH0(double latDeg, double decDeg, double h0Deg) =>
    (sinD(h0Deg) - sinD(latDeg) * sinD(decDeg)) / (cosD(latDeg) * cosD(decDeg));

/// Transit altitude `90 − |φ − δ|` (CLAUDE.md §6.6).
double transitAltitudeDeg(double latDeg, double decDeg) => 90 - (latDeg - decDeg).abs();

/// Transit azimuth: due south (180) when δ < φ, else due north (0).
double transitAzimuthDeg(double latDeg, double decDeg) => decDeg < latDeg ? 180 : 0;

/// Finds the instant near [guess] at which the body's hour angle equals the
/// value returned by [targetH] (re-evaluated each step for moving bodies).
///
/// Each step converts the remaining hour-angle difference to clock time:
/// `Δt = ΔH / 15 / 1.0027379` hours. For a fixed star the first step is exact,
/// which is the closed-form solution of CLAUDE.md §6.6.
DateTime solveHourAngle(
  PositionFn position,
  Observer observer,
  DateTime guess,
  double Function(Equatorial eq) targetH,
) {
  var t = guess;
  for (var i = 0; i < 6; i++) {
    final eq = position(t);
    final h = hourAngleDeg(lstDeg(t, observer.lonDeg), eq.raDeg);
    final dH = norm180(targetH(eq) - h);
    final dtHours = dH / 15 / siderealRatio;
    t = addHours(t, dtHours);
    if (dtHours.abs() < 1e-5) break; // < 0.04 s
  }
  return t;
}

/// Rise, transit and set for the transit **nearest** to [around] (CLAUDE.md §6.6).
///
/// Each event is computed from the transit, not from "now", so the rise may
/// fall on the previous day and the set on the next.
RiseTransitSet riseTransitSet(
  PositionFn position,
  Observer observer,
  DateTime around, {
  double h0Deg = h0Star,
}) {
  final lat = observer.latDeg;
  final transit = solveHourAngle(position, observer, around.toUtc(), (_) => 0);
  final decAtTransit = position(transit).decDeg;
  final c = cosH0(lat, decAtTransit, h0Deg);

  final transitAlt = transitAltitudeDeg(lat, decAtTransit);
  final transitAz = transitAzimuthDeg(lat, decAtTransit);

  if (c < -1) {
    return RiseTransitSet(kind: RiseSetKind.circumpolar, transit: transit, transitAltDeg: transitAlt, transitAzDeg: transitAz);
  }
  if (c > 1) {
    return RiseTransitSet(kind: RiseSetKind.neverRises, transit: transit, transitAltDeg: transitAlt, transitAzDeg: transitAz);
  }

  final h0 = acosD(c);
  // H0 for the body's declination at each event; constant for fixed stars.
  double arc(Equatorial eq) => acosD(cosH0(lat, eq.decDeg, h0Deg));

  final rise = solveHourAngle(position, observer, addHours(transit, -h0 / 15 / siderealRatio), (eq) => -arc(eq));
  final set = solveHourAngle(position, observer, addHours(transit, h0 / 15 / siderealRatio), (eq) => arc(eq));

  return RiseTransitSet(
    kind: RiseSetKind.normal,
    transit: transit,
    transitAltDeg: transitAlt,
    transitAzDeg: transitAz,
    rise: rise,
    set: set,
    riseAzDeg: horizontalAt(position(rise), observer, rise).azDeg,
    setAzDeg: horizontalAt(position(set), observer, set).azDeg,
    h0HourAngleDeg: h0,
  );
}

/// Altitude curve between [start] and [end], one sample every [step].
List<AltitudeSample> altitudeSeries(
  PositionFn position,
  Observer observer,
  DateTime start,
  DateTime end, {
  Duration step = const Duration(minutes: 10),
}) {
  final out = <AltitudeSample>[];
  for (var t = start.toUtc(); !t.isAfter(end); t = t.add(step)) {
    out.add(AltitudeSample(t, horizontalAt(position(t), observer, t).altDeg));
  }
  return out;
}

/// Best viewing window inside [dark] (CLAUDE.md §6.7): the Sun below −18°
/// **and** the object above [minAltDeg]. Sampled every 2 minutes.
///
/// Returns the qualifying stretch that contains the highest point, with that
/// peak time, or null when the object never gets high enough while it is dark.
VisibilityWindow? bestViewingWindow(
  PositionFn position,
  Observer observer,
  ({DateTime start, DateTime end}) dark, {
  double minAltDeg = minViewingAltDeg,
}) {
  final samples = altitudeSeries(position, observer, dark.start, dark.end, step: const Duration(minutes: 2));
  VisibilityWindow? best;
  int? runStart;
  for (var i = 0; i <= samples.length; i++) {
    final up = i < samples.length && samples[i].altDeg >= minAltDeg;
    if (up) {
      runStart ??= i;
      continue;
    }
    if (runStart != null) {
      var peak = samples[runStart];
      for (var j = runStart; j < i; j++) {
        if (samples[j].altDeg > peak.altDeg) peak = samples[j];
      }
      if (best == null || peak.altDeg > best.peakAltDeg) {
        best = VisibilityWindow(start: samples[runStart].time, end: samples[i - 1].time, peak: peak.time, peakAltDeg: peak.altDeg);
      }
      runStart = null;
    }
  }
  if (best == null) return null;
  // Sharpen the sampled peak to the second (it is the transit when the
  // transit falls inside the window).
  final refined = _refineMaximum(position, observer, best.peak, best.start, best.end);
  return VisibilityWindow(start: best.start, end: best.end, peak: refined.time, peakAltDeg: refined.altDeg);
}

/// Ternary search for the highest altitude within ±2 min of [around],
/// clamped to [lo]…[hi]. Altitude is unimodal over such a short span.
AltitudeSample _refineMaximum(PositionFn position, Observer observer, DateTime around, DateTime lo, DateTime hi) {
  double alt(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return horizontalAt(position(t), observer, t).altDeg;
  }

  var a = math.max(around.millisecondsSinceEpoch - 120000, lo.millisecondsSinceEpoch);
  var b = math.min(around.millisecondsSinceEpoch + 120000, hi.millisecondsSinceEpoch);
  while (b - a > 1000) {
    final m1 = a + (b - a) ~/ 3;
    final m2 = b - (b - a) ~/ 3;
    if (alt(m1) < alt(m2)) {
      a = m1;
    } else {
      b = m2;
    }
  }
  final ms = (a + b) ~/ 2;
  return AltitudeSample(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true), alt(ms));
}
