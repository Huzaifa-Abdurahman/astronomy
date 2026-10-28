/// Coordinate transforms: equatorial (RA/Dec) → horizontal (Alt/Az).
library;

import 'angles.dart';
import 'models.dart';
import 'time.dart';

/// Hour angle in degrees, normalised to −180…+180 (CLAUDE.md §6.4):
/// `H = LST − α`. Negative = east of the meridian (still rising),
/// positive = west of the meridian (setting).
double hourAngleDeg(double lstDeg, double raDeg) => norm180(lstDeg - raDeg);

/// Converts equatorial to horizontal coordinates (CLAUDE.md §6.5).
///
/// ```
/// sin(alt) = sin δ · sin φ + cos δ · cos φ · cos H
/// cos(A)   = (sin δ − sin(alt) · sin φ) / (cos(alt) · cos φ)
/// A = acos(clamp(cos A, −1, 1));  if sin H > 0 then A = 360 − A
/// ```
/// A is measured from north, clockwise. Source: Meeus ch. 13.
///
/// With [refraction] the apparent altitude is returned (see [refractionDeg]).
HorizontalPosition equatorialToHorizontal({
  required double raDeg,
  required double decDeg,
  required double latDeg,
  required double lstDeg,
  bool refraction = false,
}) {
  final h = hourAngleDeg(lstDeg, raDeg);
  final sinAlt = sinD(decDeg) * sinD(latDeg) + cosD(decDeg) * cosD(latDeg) * cosD(h);
  final alt = asinD(sinAlt);

  final denom = cosD(alt) * cosD(latDeg);
  double az;
  if (denom.abs() < 1e-12) {
    // At the zenith or at a pole azimuth is undefined; pick due south/north.
    az = latDeg >= 0 ? 180 : 0;
  } else {
    final cosA = (sinD(decDeg) - sinAlt * sinD(latDeg)) / denom;
    az = acosD(cosA);
    if (sinD(h) > 0) az = 360 - az; // west of the meridian
  }

  return HorizontalPosition(
    altDeg: refraction ? alt + refractionDeg(alt) : alt,
    azDeg: az,
    hourAngleDeg: h,
  );
}

/// Alt/Az of [eq] for [observer] at instant [t].
HorizontalPosition horizontalAt(Equatorial eq, Observer observer, DateTime t, {bool refraction = false}) =>
    equatorialToHorizontal(
      raDeg: eq.raDeg,
      decDeg: eq.decDeg,
      latDeg: observer.latDeg,
      lstDeg: lstDeg(t, observer.lonDeg),
      refraction: refraction,
    );

/// Atmospheric refraction in degrees for a true altitude (Sæmundsson / Meeus
/// eq. 16.4 as given in CLAUDE.md §6.5):
/// `R = 1.02 / tan(alt + 10.3 / (alt + 5.11))` arc-minutes. Zero below −1°.
double refractionDeg(double altDeg) {
  if (altDeg <= -1) return 0;
  final rArcMin = 1.02 / tanD(altDeg + 10.3 / (altDeg + 5.11));
  return rArcMin / 60;
}
