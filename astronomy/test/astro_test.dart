import 'package:astronomy/astro/angles.dart';
import 'package:astronomy/astro/coords.dart';
import 'package:astronomy/astro/models.dart';
import 'package:astronomy/astro/planets.dart';
import 'package:astronomy/astro/precession.dart';
import 'package:astronomy/astro/rise_set.dart';
import 'package:astronomy/astro/sun.dart';
import 'package:astronomy/astro/time.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test vector from CLAUDE.md §6.8.
const islamabad = Observer(latDeg: 33.6844, lonDeg: 73.0479);
final testTime = DateTime.utc(2026, 10, 28, 15); // 20:00 PKT
const m31 = Equatorial(10.6847, 41.2692);
const pkt = Duration(hours: 5);

PositionFn fixed(Equatorial eq) => (_) => eq;

/// Asserts [actual] is within [tolerance] minutes of [expected].
void expectTime(DateTime? actual, DateTime expected, double toleranceMinutes) {
  expect(actual, isNotNull);
  final diff = actual!.difference(expected).inSeconds.abs() / 60;
  expect(diff, lessThanOrEqualTo(toleranceMinutes), reason: 'got ${actual.toIso8601String()}, expected ${expected.toIso8601String()}');
}

void main() {
  group('§6.8 test vector — M31 from Islamabad, 2026-10-28 15:00 UTC', () {
    final lst = lstDeg(testTime, islamabad.lonDeg);
    final pos = equatorialToHorizontal(raDeg: m31.raDeg, decDeg: m31.decDeg, latDeg: islamabad.latDeg, lstDeg: lst);

    test('Julian Date', () => expect(julianDate(testTime), closeTo(2461342.125, 0.0001)));
    test('Days since J2000', () => expect(daysSinceJ2000(testTime), closeTo(9797.125, 0.0001)));
    test('GMST', () => expect(gmstDeg(testTime), closeTo(261.971, 0.01)));
    test('LST', () => expect(lst, closeTo(335.019, 0.01)));
    test('Hour angle', () => expect(pos.hourAngleDeg, closeTo(-35.666, 0.01)));
    test('Altitude (no refraction)', () => expect(pos.altDeg, closeTo(60.92, 0.05)));
    test('Azimuth', () {
      expect(pos.azDeg, closeTo(64.38, 0.1));
      expect(pos.compass, 'ENE');
    });
    test('H0 with h0 = 0', () {
      expect(acosD(cosH0(islamabad.latDeg, m31.decDeg, 0)), closeTo(125.80, 0.05));
    });

    final rts = riseTransitSet(fixed(m31), islamabad, testTime, h0Deg: 0);
    test('Transit ≈ 22:22 PKT', () {
      expect(rts.kind, RiseSetKind.normal);
      expectTime(rts.transit, DateTime.utc(2026, 10, 28, 22, 22).subtract(pkt), 2);
    });
    test('Rise ≈ 14:00 PKT, set ≈ 06:44 PKT next day', () {
      expectTime(rts.rise, DateTime.utc(2026, 10, 28, 14, 0).subtract(pkt), 3);
      expectTime(rts.set, DateTime.utc(2026, 10, 29, 6, 44).subtract(pkt), 3);
    });
    test('Transit altitude', () {
      expect(rts.transitAltDeg, closeTo(82.4, 0.05));
      expect(rts.transitAzDeg, 0, reason: 'δ > φ, so M31 culminates north of the zenith');
    });
  });

  group('§6.8 cross-checks', () {
    test('Vega → alt ≈ 45.4°, az ≈ 293°', () {
      final p = horizontalAt(const Equatorial(279.23, 38.78), islamabad, testTime);
      expect(p.altDeg, closeTo(45.4, 0.1));
      expect(p.azDeg, closeTo(293, 0.5));
    });
    test('Pleiades → alt ≈ 19.6°, az ≈ 73.5°', () {
      final p = horizontalAt(const Equatorial(56.75, 24.12), islamabad, testTime);
      expect(p.altDeg, closeTo(19.6, 0.1));
      expect(p.azDeg, closeTo(73.5, 0.5));
    });
  });

  group('angles', () {
    test('normalisation', () {
      expect(norm360(-30), 330);
      expect(norm360(725), 5);
      expect(norm180(190), -170);
      expect(norm180(-190), 170);
    });
    test('16-point compass', () {
      expect(compass16(0), 'N');
      expect(compass16(359), 'N');
      expect(compass16(11.3), 'NNE');
      expect(compass16(90), 'E');
      expect(compass16(247.5), 'WSW');
    });
    test('RA/Dec formatting', () {
      expect(formatRa(10.6847), '00h42m44s');
      expect(formatDec(41.2692), '+41°16′09″');
    });
  });

  group('rise/set edge cases', () {
    test('Polaris never sets from Islamabad', () {
      final r = riseTransitSet(fixed(const Equatorial(37.95, 89.26)), islamabad, testTime);
      expect(r.kind, RiseSetKind.circumpolar);
      expect(r.rise, isNull);
    });
    test('A far-southern object never rises from Islamabad', () {
      final r = riseTransitSet(fixed(const Equatorial(80, -70)), islamabad, testTime);
      expect(r.kind, RiseSetKind.neverRises);
    });
    test('Transit is the one nearest to the reference time', () {
      final r = riseTransitSet(fixed(m31), islamabad, testTime);
      expect(r.transit.difference(testTime).inHours.abs(), lessThanOrEqualTo(12));
    });
  });

  group('refraction', () {
    test('about 34′ at the horizon, ~0 at the zenith', () {
      expect(refractionDeg(0) * 60, closeTo(29, 6));
      expect(refractionDeg(89.9), lessThan(0.01));
      expect(refractionDeg(-2), 0);
    });
  });

  group('Sun and darkness', () {
    test('Sun is near RA 213°, Dec −13° on 28 Oct 2026', () {
      final s = sunPosition(testTime);
      expect(s.raDeg, closeTo(213.5, 1.0));
      expect(s.decDeg, closeTo(-13.0, 0.5));
    });
    test('Islamabad has astronomical darkness tonight, in the right order', () {
      final n = nightFor(islamabad, testTime);
      expect(n.hasDarkness, isTrue);
      expect(n.sunset!.isBefore(n.darkStart!), isTrue);
      expect(n.darkStart!.isBefore(n.solarMidnight), isTrue);
      expect(n.solarMidnight.isBefore(n.darkEnd!), isTrue);
      expect(n.darkEnd!.isBefore(n.sunrise!), isTrue);
      // Sun at −18° at both ends of the dark window.
      expect(sunAltitudeDeg(islamabad, n.darkStart!), closeTo(-18, 0.1));
      expect(sunAltitudeDeg(islamabad, n.darkEnd!), closeTo(-18, 0.1));
      expect(sunAltitudeDeg(islamabad, n.sunset!), closeTo(-0.833, 0.1));
    });
    test('Sunset in Islamabad on 28 Oct is about 17:20 PKT', () {
      final n = nightFor(islamabad, testTime);
      expectTime(n.sunset, DateTime.utc(2026, 10, 28, 17, 20).subtract(pkt), 10);
    });
    test('No astronomical darkness at 65° N in midsummer', () {
      final n = nightFor(const Observer(latDeg: 65, lonDeg: 25), DateTime.utc(2026, 6, 21, 12));
      expect(n.hasDarkness, isFalse);
    });
    test('M31 best window peaks at transit inside the dark window', () {
      final n = nightFor(islamabad, testTime);
      final w = bestViewingWindow(fixed(m31), islamabad, n.dark!);
      final r = riseTransitSet(fixed(m31), islamabad, n.solarMidnight);
      expect(w, isNotNull);
      expectTime(w!.peak, DateTime.utc(2026, 10, 28, 22, 22).subtract(pkt), 1);
      expect(w.peak.difference(r.transit).inSeconds.abs(), lessThan(5), reason: 'peak should be the exact transit');
      expect(w.peakAltDeg, closeTo(82.4, 0.1));
    });
  });

  group('planets (§6.10) vs JPL Horizons, 2026-10-28 15:00 UTC', () {
    // Apparent RA/Dec of date from https://ssd.jpl.nasa.gov/api/horizons.api.
    const reference = {
      Planet.mercury: Equatorial(226.50388, -19.94384),
      Planet.venus: Equatorial(203.97239, -16.04778),
      Planet.mars: Equatorial(139.83885, 17.22768),
      Planet.jupiter: Equatorial(146.44700, 14.19420),
      Planet.saturn: Equatorial(9.79146, 1.29015),
    };
    for (final entry in reference.entries) {
      test('${entry.key.name} within 0.1°', () {
        final p = planetPosition(entry.key, testTime);
        expect(norm180(p.raDeg - entry.value.raDeg).abs(), lessThan(0.1));
        expect((p.decDeg - entry.value.decDeg).abs(), lessThan(0.1));
      });
    }
    test('topocentric Moon from Islamabad within 0.3°', () {
      final p = moonPosition(testTime, islamabad);
      expect(norm180(p.raDeg - 66.90341).abs(), lessThan(0.3));
      expect((p.decDeg - 26.10282).abs(), lessThan(0.3));
      final h = horizontalAt(p, islamabad, testTime);
      expect(h.altDeg, closeTo(12.678, 0.3));
      expect(h.azDeg, closeTo(66.919, 0.3));
    });
  });

  group('precession (optional, §6.9)', () {
    test('M31 drifts about 0.36° in RA between J2000 and 2026', () {
      final p = precessFromJ2000(m31, testTime);
      expect(p.raDeg - m31.raDeg, closeTo(0.36, 0.03));
    });
    test('no change at J2000', () {
      final p = precessFromJ2000(m31, DateTime.utc(2000, 1, 1, 12));
      expect(p.raDeg, closeTo(m31.raDeg, 1e-6));
      expect(p.decDeg, closeTo(m31.decDeg, 1e-6));
    });
  });
}
