/// Approximate positions of the Moon and planets (CLAUDE.md §6.10).
///
/// Implements Paul Schlyter, "How to compute planetary positions"
/// (https://stjarnhimlen.se/comp/ppcomp.html). Accuracy is about 1–2′ for the
/// planets and a few arc-minutes for the Moon — plenty for pointing a phone.
/// Results are referred to the equinox of date, so no precession is needed.
library;

import 'dart:math' as math;

import 'angles.dart';
import 'coords.dart';
import 'models.dart';
import 'time.dart';

enum Planet { mercury, venus, mars, jupiter, saturn, uranus, neptune }

/// Schlyter's day number: d = 0.0 at 1999-12-31T00:00 UT, i.e. `JD − 2451543.5`.
double schlyterDay(DateTime t) => julianDate(t) - 2451543.5;

/// Keplerian orbital elements at day [d] (degrees, AU or Earth radii).
class _Elements {
  const _Elements(this.n, this.i, this.w, this.a, this.e, this.m);

  final double n; // longitude of the ascending node
  final double i; // inclination to the ecliptic
  final double w; // argument of perihelion
  final double a; // semi-major axis
  final double e; // eccentricity
  final double m; // mean anomaly
}

_Elements _sunElements(double d) => _Elements(
      0, 0, 282.9404 + 4.70935e-5 * d, 1.0, 0.016709 - 1.151e-9 * d, norm360(356.0470 + 0.9856002585 * d));

_Elements _moonElements(double d) => _Elements(
      norm360(125.1228 - 0.0529538083 * d), 5.1454, norm360(318.0634 + 0.1643573223 * d), 60.2666, 0.054900,
      norm360(115.3654 + 13.0649929509 * d));

_Elements _planetElements(Planet p, double d) => switch (p) {
      Planet.mercury => _Elements(48.3313 + 3.24587e-5 * d, 7.0047 + 5.00e-8 * d, 29.1241 + 1.01444e-5 * d, 0.387098,
          0.205635 + 5.59e-10 * d, norm360(168.6562 + 4.0923344368 * d)),
      Planet.venus => _Elements(76.6799 + 2.46590e-5 * d, 3.3946 + 2.75e-8 * d, 54.8910 + 1.38374e-5 * d, 0.723330,
          0.006773 - 1.302e-9 * d, norm360(48.0052 + 1.6021302244 * d)),
      Planet.mars => _Elements(49.5574 + 2.11081e-5 * d, 1.8497 - 1.78e-8 * d, 286.5016 + 2.92961e-5 * d, 1.523688,
          0.093405 + 2.516e-9 * d, norm360(18.6021 + 0.5240207766 * d)),
      Planet.jupiter => _Elements(100.4542 + 2.76854e-5 * d, 1.3030 - 1.557e-7 * d, 273.8777 + 1.64505e-5 * d, 5.20256,
          0.048498 + 4.469e-9 * d, norm360(19.8950 + 0.0830853001 * d)),
      Planet.saturn => _Elements(113.6634 + 2.38980e-5 * d, 2.4886 - 1.081e-7 * d, 339.3939 + 2.97661e-5 * d, 9.55475,
          0.055546 - 9.499e-9 * d, norm360(316.9670 + 0.0334442282 * d)),
      Planet.uranus => _Elements(74.0005 + 1.3978e-5 * d, 0.7733 + 1.9e-8 * d, 96.6612 + 3.0565e-5 * d,
          19.18171 - 1.55e-8 * d, 0.047318 + 7.45e-9 * d, norm360(142.5905 + 0.011725806 * d)),
      Planet.neptune => _Elements(131.7806 + 3.0173e-5 * d, 1.7700 - 2.55e-7 * d, 272.8461 - 6.027e-6 * d,
          30.05826 + 3.313e-8 * d, 0.008606 + 2.15e-9 * d, norm360(260.2471 + 0.005995147 * d)),
    };

/// Obliquity of the ecliptic at day [d].
double _obliquity(double d) => 23.4393 - 3.563e-7 * d;

/// Solves Kepler's equation `M = E − e·sin E` by Newton iteration (degrees).
double _eccentricAnomaly(double mDeg, double e) {
  var ea = mDeg + e * radToDeg * sinD(mDeg) * (1 + e * cosD(mDeg));
  for (var k = 0; k < 10; k++) {
    final next = ea - (ea - e * radToDeg * sinD(ea) - mDeg) / (1 - e * cosD(ea));
    if ((next - ea).abs() < 1e-6) return next;
    ea = next;
  }
  return ea;
}

/// Position in the orbital plane → (true anomaly v, distance r).
({double v, double r}) _orbitPosition(_Elements el) {
  final ea = _eccentricAnomaly(el.m, el.e);
  final xv = el.a * (cosD(ea) - el.e);
  final yv = el.a * (math.sqrt(1 - el.e * el.e) * sinD(ea));
  return (v: atan2D(yv, xv), r: math.sqrt(xv * xv + yv * yv));
}

/// Orbit → ecliptic rectangular coordinates centred on the primary.
({double x, double y, double z}) _eclipticXyz(_Elements el, double v, double r) {
  final vw = v + el.w;
  return (
    x: r * (cosD(el.n) * cosD(vw) - sinD(el.n) * sinD(vw) * cosD(el.i)),
    y: r * (sinD(el.n) * cosD(vw) + cosD(el.n) * sinD(vw) * cosD(el.i)),
    z: r * (sinD(vw) * sinD(el.i)),
  );
}

/// Ecliptic rectangular → equatorial RA/Dec of date.
Equatorial _toEquatorial(double x, double y, double z, double d) {
  final ecl = _obliquity(d);
  final xe = x;
  final ye = y * cosD(ecl) - z * sinD(ecl);
  final ze = y * sinD(ecl) + z * cosD(ecl);
  return Equatorial(norm360(atan2D(ye, xe)), atan2D(ze, math.sqrt(xe * xe + ye * ye)));
}

/// Geocentric rectangular position of the Sun (AU, ecliptic).
({double x, double y}) _sunXy(double d) {
  final el = _sunElements(d);
  final o = _orbitPosition(el);
  final lon = o.v + el.w;
  return (x: o.r * cosD(lon), y: o.r * sinD(lon));
}

/// Geocentric RA/Dec of a planet at [t], with the Jupiter/Saturn mutual
/// perturbations from Schlyter §11.
Equatorial planetPosition(Planet p, DateTime t) {
  final d = schlyterDay(t);
  final el = _planetElements(p, d);
  final o = _orbitPosition(el);
  var h = _eclipticXyz(el, o.v, o.r);

  if (p == Planet.jupiter || p == Planet.saturn || p == Planet.uranus) {
    final mj = _planetElements(Planet.jupiter, d).m;
    final ms = _planetElements(Planet.saturn, d).m;
    final mu = _planetElements(Planet.uranus, d).m;
    var lon = atan2D(h.y, h.x);
    var lat = atan2D(h.z, math.sqrt(h.x * h.x + h.y * h.y));
    if (p == Planet.jupiter) {
      lon += -0.332 * sinD(2 * mj - 5 * ms - 67.6) -
          0.056 * sinD(2 * mj - 2 * ms + 21) +
          0.042 * sinD(3 * mj - 5 * ms + 21) -
          0.036 * sinD(mj - 2 * ms) +
          0.022 * cosD(mj - ms) +
          0.023 * sinD(2 * mj - 3 * ms + 52) -
          0.016 * sinD(mj - 5 * ms - 69);
    } else if (p == Planet.saturn) {
      lon += 0.812 * sinD(2 * mj - 5 * ms - 67.6) -
          0.229 * cosD(2 * mj - 4 * ms - 2) +
          0.119 * sinD(mj - 2 * ms - 3) +
          0.046 * sinD(2 * mj - 6 * ms - 69) +
          0.014 * sinD(mj - 3 * ms + 32);
      lat += -0.020 * cosD(2 * mj - 4 * ms - 2) + 0.018 * sinD(2 * mj - 6 * ms - 49);
    } else {
      lon += 0.040 * sinD(ms - 2 * mu + 6) + 0.035 * sinD(ms - 3 * mu + 33) - 0.015 * sinD(mj - mu + 20);
    }
    final r = o.r;
    h = (x: r * cosD(lon) * cosD(lat), y: r * sinD(lon) * cosD(lat), z: r * sinD(lat));
  }

  final s = _sunXy(d);
  return _toEquatorial(h.x + s.x, h.y + s.y, h.z, d);
}

/// Topocentric RA/Dec of the Moon at [t] for [observer] (Schlyter §6 and §13).
///
/// The Moon is close enough that parallax shifts it by up to ~1°, so the
/// observer's position matters, unlike for the planets.
Equatorial moonPosition(DateTime t, Observer observer) {
  final d = schlyterDay(t);
  final el = _moonElements(d);
  final o = _orbitPosition(el);
  final g = _eclipticXyz(el, o.v, o.r);
  var lon = atan2D(g.y, g.x);
  var lat = atan2D(g.z, math.sqrt(g.x * g.x + g.y * g.y));
  var r = o.r;

  final sun = _sunElements(d);
  final ms = sun.m, mm = el.m;
  final ls = ms + sun.w;
  final lm = mm + el.w + el.n;
  final dd = lm - ls; // mean elongation
  final f = lm - el.n; // argument of latitude
  lon += -1.274 * sinD(mm - 2 * dd) +
      0.658 * sinD(2 * dd) -
      0.186 * sinD(ms) -
      0.059 * sinD(2 * mm - 2 * dd) -
      0.057 * sinD(mm - 2 * dd + ms) +
      0.053 * sinD(mm + 2 * dd) +
      0.046 * sinD(2 * dd - ms) +
      0.041 * sinD(mm - ms) -
      0.035 * sinD(dd) -
      0.031 * sinD(mm + ms) -
      0.015 * sinD(2 * f - 2 * dd) +
      0.011 * sinD(mm - 4 * dd);
  lat += -0.173 * sinD(f - 2 * dd) -
      0.055 * sinD(mm - f - 2 * dd) -
      0.046 * sinD(mm + f - 2 * dd) +
      0.033 * sinD(f + 2 * dd) +
      0.017 * sinD(2 * mm + f);
  r += -0.58 * cosD(mm - 2 * dd) - 0.46 * cosD(2 * dd);

  final geo = _toEquatorial(r * cosD(lon) * cosD(lat), r * sinD(lon) * cosD(lat), r * sinD(lat), d);

  // Topocentric correction for parallax.
  final mpar = asinD(1 / r);
  final gclat = observer.latDeg - 0.1924 * sinD(2 * observer.latDeg);
  final rho = 0.99833 + 0.00167 * cosD(2 * observer.latDeg);
  final ha = hourAngleDeg(lstDeg(t, observer.lonDeg), geo.raDeg);
  final topRa = geo.raDeg - mpar * rho * cosD(gclat) * sinD(ha) / cosD(geo.decDeg);
  double topDec;
  if (gclat.abs() < 1e-9) {
    topDec = geo.decDeg - mpar * rho * sinD(-geo.decDeg) * cosD(ha);
  } else {
    final gg = math.atan(tanD(gclat) / cosD(ha)) * radToDeg;
    topDec = geo.decDeg - mpar * rho * sinD(gclat) * sinD(gg - geo.decDeg) / sinD(gg);
  }
  return Equatorial(norm360(topRa), topDec);
}

/// Fraction of the Moon's disc that is lit, 0 (new) … 1 (full).
double moonIlluminatedFraction(DateTime t) {
  final d = schlyterDay(t);
  final el = _moonElements(d);
  final sun = _sunElements(d);
  // Mean elongation is good enough for a phase label.
  final elong = norm360(el.m + el.w + el.n - (sun.m + sun.w));
  return (1 - cosD(elong)) / 2;
}
