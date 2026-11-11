import 'package:astronomy/astro/orbit.dart';
import 'package:astronomy/data/celestrak_api.dart';
import 'package:astronomy/data/n2yo_api.dart';
import 'package:astronomy/features/satellites/satellites_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orbit math', () {
    // ISS elements from CelesTrak/N2YO TLE, epoch 2026-11-10:
    // mean motion 15.49305067 rev/day, e = 0.0007308, i = 51.6322°.
    const n = 15.49305067, e = 0.0007308;

    test('period is 1440 / mean motion', () {
      expect(periodMinutes(n), closeTo(92.945, 0.001));
    });

    test('semi-major axis from Kepler III puts the ISS near 420 km', () {
      final a = semiMajorAxisKm(n);
      expect(a, closeTo(6797.3, 0.5));
      final h = apsisHeightsKm(n, e);
      expect(h.perigeeKm, closeTo(414.2, 1));
      expect(h.apogeeKm, closeTo(424.1, 1));
    });

    test('circular speed at ISS height is about 7.66 km/s', () {
      expect(circularSpeedKmS(419), closeTo(7.66, 0.01));
    });
  });

  group('interpolation', () {
    SatSample s(int t, double lon, double az) => SatSample(
          time: DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true),
          latDeg: 10,
          lonDeg: lon,
          altKm: 420,
          azDeg: az,
          elDeg: 5,
        );

    test('halfway between two samples', () {
      final r = sampleAt([s(0, 10, 100), s(2, 12, 104)], DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true))!;
      expect(r.lonDeg, closeTo(11, 1e-9));
      expect(r.azDeg, closeTo(102, 1e-9));
    });

    test('longitude takes the short way across the ±180° seam', () {
      final r = sampleAt([s(0, 179, 0), s(2, -179, 0)], DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true))!;
      expect(r.lonDeg.abs(), closeTo(180, 1e-9));
    });

    test('azimuth takes the short way across north', () {
      final r = sampleAt([s(0, 0, 358), s(2, 0, 2)], DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true))!;
      expect(r.azDeg % 360, closeTo(0, 1e-9));
    });

    test('clamps outside the sampled range', () {
      final samples = [s(10, 1, 1), s(11, 2, 2)];
      expect(sampleAt(samples, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))!.lonDeg, 1);
      expect(sampleAt(samples, DateTime.fromMillisecondsSinceEpoch(99000, isUtc: true))!.lonDeg, 2);
      expect(sampleAt(const [], DateTime.now()), isNull);
    });
  });

  group('N2YO parsing (samples from the API documentation)', () {
    test('positions', () {
      final list = N2yoApi.parsePositions({
        'info': {'satname': 'SPACE STATION', 'satid': 25544, 'transactionscount': 5},
        'positions': [
          {
            'satlatitude': -39.90318514,
            'satlongitude': 158.28897924,
            'sataltitude': 417.85,
            'azimuth': 254.31,
            'elevation': -69.09,
            'ra': 44.77078138,
            'dec': -43.99279118,
            'timestamp': 1521354418,
          },
        ],
      });
      expect(list, hasLength(1));
      expect(list.single.altKm, 417.85);
      expect(list.single.isUp, isFalse);
      expect(list.single.time, DateTime.utc(2018, 3, 18, 6, 26, 58));
    });

    test('visual pass and its card text', () {
      final p = SatPass.fromJson({
        'startAz': 307.21,
        'startAzCompass': 'NW',
        'startEl': 13.08,
        'startUTC': 1521368025,
        'maxAz': 225.45,
        'maxAzCompass': 'SW',
        'maxEl': 78.27,
        'maxUTC': 1521368345,
        'endAz': 132.82,
        'endAzCompass': 'SE',
        'endEl': 0,
        'endUTC': 1521368660,
        'mag': -2.4,
        'duration': 485,
      });
      expect(p.pathText, 'Appears NW, climbs to 78°, gone SE after 8 min');
      expect(p.mag, -2.4);
      // Round-trips through the cache format.
      expect(SatPass.fromJson(p.toJson()).pathText, p.pathText);
    });

    test('unknown magnitude (100000) becomes null', () {
      final p = SatPass.fromJson({
        'startUTC': 0,
        'maxUTC': 0,
        'endUTC': 0,
        'startAzCompass': 'W',
        'maxAzCompass': 'S',
        'endAzCompass': 'E',
        'maxEl': 30,
        'duration': 20,
        'mag': 100000,
      });
      expect(p.mag, isNull);
      expect(p.pathText, endsWith('after 1 min'));
    });
  });

  test('CelesTrak OMM JSON parses and round-trips', () {
    final o = OrbitElements.fromJson({
      'OBJECT_NAME': 'ISS (ZARYA)',
      'NORAD_CAT_ID': 25544,
      'EPOCH': '2026-11-10T21:13:46.284672',
      'MEAN_MOTION': 15.49305067,
      'ECCENTRICITY': 0.0007308,
      'INCLINATION': 51.6322,
    });
    expect(o.epoch.isUtc, isTrue);
    expect(o.periodMin, closeTo(92.945, 0.001));
    expect(OrbitElements.fromJson(o.toJson()).epoch, o.epoch);
  });

  test('haversine: Islamabad to Lahore is about 270 km', () {
    expect(haversineKm(33.6844, 73.0479, 31.5204, 74.3587), closeTo(270, 5));
  });
}
