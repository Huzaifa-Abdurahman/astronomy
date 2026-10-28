/// Low-precision solar position and tonight's darkness window.
library;

import 'angles.dart';
import 'coords.dart';
import 'models.dart';
import 'rise_set.dart';
import 'time.dart';

/// Sun RA/Dec (CLAUDE.md §6.7), accurate to about 0.01° for 1950–2050.
///
/// ```
/// n = D (days since J2000)
/// L = 280.460 + 0.9856474·n          mean longitude
/// g = 357.528 + 0.9856003·n          mean anomaly
/// λ = L + 1.915·sin g + 0.020·sin 2g ecliptic longitude
/// ε = 23.439 − 0.0000004·n           obliquity
/// α = atan2(cos ε · sin λ, cos λ);  δ = asin(sin ε · sin λ)
/// ```
/// Source: *Astronomical Almanac*, "Low-precision formulas for the Sun".
Equatorial sunPosition(DateTime t) {
  final n = daysSinceJ2000(t);
  final l = norm360(280.460 + 0.9856474 * n);
  final g = norm360(357.528 + 0.9856003 * n);
  final lambda = l + 1.915 * sinD(g) + 0.020 * sinD(2 * g);
  final eps = 23.439 - 0.0000004 * n;
  final ra = norm360(atan2D(cosD(eps) * sinD(lambda), cosD(lambda)));
  final dec = asinD(sinD(eps) * sinD(lambda));
  return Equatorial(ra, dec);
}

double sunAltitudeDeg(Observer observer, DateTime t) => horizontalAt(sunPosition(t), observer, t).altDeg;

/// Sunset, astronomical darkness and sunrise for one night (UTC instants).
class NightInfo {
  const NightInfo({
    required this.solarMidnight,
    required this.sunset,
    required this.sunrise,
    required this.darkStart,
    required this.darkEnd,
  });

  /// The Sun's lower culmination: the middle of the night.
  final DateTime solarMidnight;

  /// Null when the Sun does not set (or rise) that day.
  final DateTime? sunset;
  final DateTime? sunrise;

  /// Sun crosses −18° going down / coming up. Null when it never gets that
  /// low (e.g. summer at high latitudes).
  final DateTime? darkStart;
  final DateTime? darkEnd;

  bool get hasDarkness => darkStart != null && darkEnd != null;

  ({DateTime start, DateTime end})? get dark => hasDarkness ? (start: darkStart!, end: darkEnd!) : null;
}

/// The night that "tonight" refers to at instant [now].
///
/// That is the first solar midnight after `now − 6 h`: in the afternoon and
/// evening it is the coming night, in the small hours the night in progress.
NightInfo nightFor(Observer observer, DateTime now) {
  final ref = now.toUtc().subtract(const Duration(hours: 6));
  // The nearest lower culmination to ref + 12 h lies in [ref, ref + 24 h].
  final midnight = solveHourAngle(sunPosition, observer, ref.add(const Duration(hours: 12)), (_) => 180);
  final noonBefore = midnight.subtract(const Duration(hours: 12));
  final noonAfter = midnight.add(const Duration(hours: 12));

  final setDay = riseTransitSet(sunPosition, observer, noonBefore, h0Deg: h0Sun);
  final riseDay = riseTransitSet(sunPosition, observer, noonAfter, h0Deg: h0Sun);
  final duskDay = riseTransitSet(sunPosition, observer, noonBefore, h0Deg: h0AstronomicalTwilight);
  final dawnDay = riseTransitSet(sunPosition, observer, noonAfter, h0Deg: h0AstronomicalTwilight);

  DateTime? darkStart = duskDay.set;
  DateTime? darkEnd = dawnDay.rise;
  // Polar night: the Sun stays below −18° all day, so it is dark noon to noon.
  if (duskDay.kind == RiseSetKind.neverRises) darkStart = noonBefore;
  if (dawnDay.kind == RiseSetKind.neverRises) darkEnd = noonAfter;

  return NightInfo(
    solarMidnight: midnight,
    sunset: setDay.set,
    sunrise: riseDay.rise,
    darkStart: darkStart,
    darkEnd: darkEnd,
  );
}
