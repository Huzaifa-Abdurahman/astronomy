import 'package:astronomy/astro/coords.dart';
import 'package:astronomy/astro/models.dart';
import 'package:astronomy/astro/planets.dart';
import 'package:astronomy/astro/rise_set.dart';
import 'package:astronomy/astro/sky_track.dart';
import 'package:astronomy/astro/sun.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const islamabad = Observer(latDeg: 33.6844, lonDeg: 73.0479);
  final t = DateTime.utc(2026, 10, 28, 15);
  const m31 = Equatorial(10.6847, 41.2692);
  Equatorial m31Fn(DateTime _) => m31;

  group('tonight\'s track', () {
    final rts = riseTransitSet(m31Fn, islamabad, t);
    final track = skyTrackTonight(m31Fn, islamabad, rts);

    test('runs from rise to set and peaks at the transit altitude', () {
      expect(track.first.time, rts.rise);
      expect(track.last.time, rts.set);
      expect(track.first.altDeg, closeTo(0, 1));
      expect(track.last.altDeg, closeTo(0, 1));
      final maxAlt = track.map((p) => p.altDeg).reduce((a, b) => a > b ? a : b);
      expect(maxAlt, closeTo(rts.transitAltDeg, 0.6)); // 5-minute sampling + refraction
    });

    test('interpolated point at the test time matches the engine', () {
      final p = trackPointAt(track, t)!;
      final h = horizontalAt(m31, islamabad, t, refraction: true);
      expect(p.altDeg, closeTo(h.altDeg, 0.1));
      expect(p.azDeg, closeTo(h.azDeg, 0.2));
    });

    test('fractions map to the ends', () {
      expect(trackPointAtFraction(track, 0).time, track.first.time);
      expect(trackPointAtFraction(track, 1).time, track.last.time);
    });

    test('a circumpolar object gets a 24 h loop, a never-rising one nothing', () {
      Equatorial polaris(DateTime _) => const Equatorial(37.95, 89.26);
      final loop = skyTrackTonight(polaris, islamabad, riseTransitSet(polaris, islamabad, t));
      expect(loop.last.time.difference(loop.first.time).inHours, 24);
      expect(loop.every((p) => p.isUp), isTrue);
      Equatorial southPole(DateTime _) => const Equatorial(0, -85);
      expect(skyTrackTonight(southPole, islamabad, riseTransitSet(southPole, islamabad, t)), isEmpty);
    });
  });

  group('satellite pass arc', () {
    final arc = passArc(
      start: DateTime.utc(2026, 11, 11, 12, 48),
      startAltDeg: 0,
      startAzDeg: 213.6,
      max: DateTime.utc(2026, 11, 11, 12, 53, 15),
      maxAltDeg: 47.3,
      maxAzDeg: 135.5,
      end: DateTime.utc(2026, 11, 11, 12, 58, 30),
      endAltDeg: 14.2,
      endAzDeg: 52.5,
    );

    test('passes exactly through the three given points', () {
      expect(arc.first.altDeg, closeTo(0, 1e-6));
      expect(arc.first.azDeg, closeTo(213.6, 1e-6));
      final mid = arc[arc.length ~/ 2];
      expect(mid.altDeg, closeTo(47.3, 1e-6));
      expect(mid.azDeg, closeTo(135.5, 1e-6));
      expect(arc.last.altDeg, closeTo(14.2, 1e-6));
      expect(arc.last.azDeg, closeTo(52.5, 1e-6));
    });

    test('times run forward and the peak is at the middle sample', () {
      for (var i = 1; i < arc.length; i++) {
        expect(arc[i].time.isAfter(arc[i - 1].time), isTrue);
      }
      expect(arc[arc.length ~/ 2].time, DateTime.utc(2026, 11, 11, 12, 53, 15));
    });

    test('is smooth: no sample jumps more than a few degrees', () {
      for (var i = 1; i < arc.length; i++) {
        expect((arc[i].altDeg - arc[i - 1].altDeg).abs(), lessThan(6));
      }
    });
  });

  group('dome projection', () {
    test('zenith at the centre, horizon on the rim, north up, east right', () {
      expect(domeXy(90, 0).x, closeTo(0, 1e-9));
      expect(domeXy(90, 0).y, closeTo(0, 1e-9));
      expect(domeXy(0, 0).y, closeTo(-1, 1e-9)); // north: top
      expect(domeXy(0, 90).x, closeTo(1, 1e-9)); // east: right
      expect(domeXy(45, 180).y, closeTo(0.5, 1e-9)); // south, halfway up
    });

    test('heading rotates the dome so "ahead" is at the top', () {
      final p = domeXy(0, 90, headingDeg: 90);
      expect(p.x, closeTo(0, 1e-9));
      expect(p.y, closeTo(-1, 1e-9));
    });

    test('fist rule', () {
      expect(fistsText(61), 'about 6 fists above the horizon');
      expect(fistsText(12), 'about one fist above the horizon');
      expect(fistsText(85), 'almost straight overhead');
    });
  });

  group('solar system', () {
    final system = solarSystemAt(t);

    test('Earth is at 1 AU with zero elongation; inner planets stay near the Sun', () {
      final earth = system.firstWhere((p) => p.planet == null);
      expect(earth.distanceFromSunAu, closeTo(1, 0.02));
      expect(earth.elongationDeg, 0);
      expect(system.firstWhere((p) => p.planet == Planet.mercury).elongationDeg.abs(), lessThan(28.5));
      expect(system.firstWhere((p) => p.planet == Planet.venus).elongationDeg.abs(), lessThan(48));
    });

    test('distances match the semi-major axes roughly', () {
      expect(system.firstWhere((p) => p.planet == Planet.jupiter).distanceFromSunAu, closeTo(5.2, 0.3));
      expect(system.firstWhere((p) => p.planet == Planet.saturn).distanceFromSunAu, closeTo(9.55, 0.6));
    });

    test('elongation sign agrees with RA: east of the Sun means larger RA', () {
      // Jupiter on 2026-10-28 15:00 UTC: compare with the geocentric positions.
      final sunRa = sunPosition(t).raDeg;
      final jupRa = planetPosition(Planet.jupiter, t).raDeg;
      final diff = ((jupRa - sunRa + 540) % 360) - 180;
      final elong = system.firstWhere((p) => p.planet == Planet.jupiter).elongationDeg;
      expect(elong.sign, diff.sign);
    });
  });
}
