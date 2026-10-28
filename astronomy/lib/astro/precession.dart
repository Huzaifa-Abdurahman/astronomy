/// Precession of J2000 catalog coordinates to the equinox of date.
library;

import 'angles.dart';
import 'models.dart';
import 'time.dart';

/// Rigorous precession from J2000.0 to the date of [t] (CLAUDE.md §6.9).
///
/// With the starting epoch at J2000 (T = 0), Meeus eq. 21.3 reduces to
/// ```
/// t = (JD − 2451545) / 36525
/// ζ = 2306.2181″t + 0.30188″t² + 0.017998″t³
/// z = 2306.2181″t + 1.09468″t² + 0.018203″t³
/// θ = 2004.3109″t − 0.42665″t² − 0.041833″t³
/// A = cos δ0 · sin(α0 + ζ)
/// B = cos θ · cos δ0 · cos(α0 + ζ) − sin θ · sin δ0
/// C = sin θ · cos δ0 · cos(α0 + ζ) + cos θ · sin δ0
/// α = atan2(A, B) + z;   δ = asin(C)
/// ```
/// Source: Meeus, *Astronomical Algorithms*, ch. 21, eq. 21.3–21.4.
Equatorial precessFromJ2000(Equatorial j2000, DateTime t) {
  final c = (julianDate(t) - jdJ2000) / 36525;
  final zeta = (2306.2181 * c + 0.30188 * c * c + 0.017998 * c * c * c) / 3600;
  final z = (2306.2181 * c + 1.09468 * c * c + 0.018203 * c * c * c) / 3600;
  final theta = (2004.3109 * c - 0.42665 * c * c - 0.041833 * c * c * c) / 3600;

  final a0 = j2000.raDeg + zeta;
  final d0 = j2000.decDeg;
  final a = cosD(d0) * sinD(a0);
  final b = cosD(theta) * cosD(d0) * cosD(a0) - sinD(theta) * sinD(d0);
  final cc = sinD(theta) * cosD(d0) * cosD(a0) + cosD(theta) * sinD(d0);

  return Equatorial(norm360(atan2D(a, b) + z), asinD(cc));
}
