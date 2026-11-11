import 'angles.dart';
import 'coords.dart';
import 'models.dart';
import 'rise_set.dart';
import 'time.dart';

/// Every intermediate value of the RA/Dec → Alt/Az calculation, for the Math
/// screen (CLAUDE.md §6.1–6.6). Pure Dart and fully offline.
///
/// It calls the same functions the rest of the app uses, so the numbers shown
/// on the Math screen are exactly the ones behind every other screen.
class Workings {
  const Workings({
    required this.time,
    required this.latDeg,
    required this.lonDeg,
    required this.raDeg,
    required this.decDeg,
    required this.jd,
    required this.d,
    required this.gmst,
    required this.lst,
    required this.hourAngle,
    required this.sinAlt,
    required this.altDeg,
    required this.cosA,
    required this.aRaw,
    required this.azDeg,
    required this.refractionDeg,
    required this.cosH0,
    required this.h0Deg,
    required this.transitAltDeg,
    required this.transitAzDeg,
  });

  final DateTime time;

  /// Inputs: φ, λ, α, δ (degrees).
  final double latDeg;
  final double lonDeg;
  final double raDeg;
  final double decDeg;

  /// Step 1: Julian Date.
  final double jd;

  /// Step 2: days since J2000.
  final double d;

  /// Step 3: Greenwich Mean Sidereal Time (°).
  final double gmst;

  /// Step 4: Local Sidereal Time (°).
  final double lst;

  /// Step 5: hour angle H = LST − α, normalised to −180…+180 (°).
  final double hourAngle;

  /// Step 6: altitude.
  final double sinAlt;
  final double altDeg;

  /// Step 7: azimuth. [aRaw] is acos(cos A) before the west-side flip.
  final double cosA;
  final double aRaw;
  final double azDeg;

  /// Optional refraction correction at [altDeg] (°), 0 below −1°.
  final double refractionDeg;

  /// Rise/set: cos H0 for h0 = −0.5667°; < −1 circumpolar, > 1 never rises.
  final double cosH0;

  /// Semi-diurnal arc H0 (°), null when the object never rises or sets.
  final double? h0Deg;
  final double transitAltDeg;
  final double transitAzDeg;

  bool get westOfMeridian => sinD(hourAngle) > 0;
  bool get circumpolar => cosH0 < -1;
  bool get neverRises => cosH0 > 1;
  String get compass => compass16(azDeg);
  double get apparentAltDeg => altDeg + refractionDeg;
}

/// Works through §6.1–6.6 for [eq] seen from [observer] at [t] (UTC).
Workings computeWorkings(Equatorial eq, Observer observer, DateTime t) {
  final utc = t.toUtc();
  final lat = observer.latDeg, ra = eq.raDeg, dec = eq.decDeg;

  final jd = julianDate(utc); // §6.1
  final d = daysSinceJ2000(utc); // §6.2
  final gmst = gmstDeg(utc); // §6.3
  final lst = lstDeg(utc, observer.lonDeg); // §6.4
  final h = hourAngleDeg(lst, ra); // §6.4

  // §6.5, written out step by step. The final values are cross-checked
  // against equatorialToHorizontal() in the tests.
  final sinAlt = sinD(dec) * sinD(lat) + cosD(dec) * cosD(lat) * cosD(h);
  final alt = asinD(sinAlt);
  final denom = cosD(alt) * cosD(lat);
  final cosA = denom.abs() < 1e-12 ? 0.0 : ((sinD(dec) - sinAlt * sinD(lat)) / denom).clamp(-1.0, 1.0);
  final aRaw = acosD(cosA);
  final az = horizontalAt(eq, observer, utc).azDeg;

  // §6.6
  final c = cosH0(lat, dec, h0Star);
  return Workings(
    time: utc,
    latDeg: lat,
    lonDeg: observer.lonDeg,
    raDeg: ra,
    decDeg: dec,
    jd: jd,
    d: d,
    gmst: gmst,
    lst: lst,
    hourAngle: h,
    sinAlt: sinAlt,
    altDeg: alt,
    cosA: cosA,
    aRaw: aRaw,
    azDeg: az,
    refractionDeg: refractionDeg(alt),
    cosH0: c,
    h0Deg: c.abs() <= 1 ? acosD(c) : null,
    transitAltDeg: transitAltitudeDeg(lat, dec),
    transitAzDeg: transitAzimuthDeg(lat, dec),
  );
}
