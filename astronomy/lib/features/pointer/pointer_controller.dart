import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../astro/angles.dart';

/// Live phone orientation for the pointer (CLAUDE.md §8).
///
/// * Heading comes from `flutter_compass` and is smoothed with a low-pass
///   filter (α = 0.15) that handles the 359° → 0° wrap.
/// * Pitch is the elevation of the back camera's line of sight, from the
///   accelerometer: hold the phone upright and point the camera at the sky.
///   With gravity g = (ax, ay, az), the camera axis is −z, so
///   `pitch = asin(−az / |g|)`: 0° at the horizon, 90° straight up.
///
/// Both are null where the sensor is missing (web, most emulators).

const _alpha = 0.15;

final headingProvider = StreamProvider.autoDispose<double?>((ref) {
  final events = FlutterCompass.events;
  if (kIsWeb || events == null) return Stream.value(null);
  double? smooth;
  return events.map((e) {
    final raw = e.heading;
    if (raw == null) return smooth;
    if (smooth == null) {
      smooth = norm360(raw);
    } else {
      smooth = norm360(smooth! + _alpha * norm180(raw - smooth!));
    }
    return smooth;
  });
});

final pitchProvider = StreamProvider.autoDispose<double?>((ref) {
  if (kIsWeb) return Stream.value(null);
  double? smooth;
  return accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).map((e) {
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (g < 1e-3) return smooth;
    final pitch = asinD((-e.z / g).clamp(-1.0, 1.0));
    smooth = smooth == null ? pitch : smooth! + _alpha * (pitch - smooth!);
    return smooth;
  }).handleError((Object _) {});
});

/// How far the phone is from the target, and what to do about it.
class PointerDelta {
  const PointerDelta({required this.azDeg, required this.altDeg});

  /// Positive: turn right. Null when there is no compass.
  final double? azDeg;

  /// Positive: tilt up. Null when there is no accelerometer.
  final double? altDeg;

  /// Combined angular distance to the target, when both sensors exist.
  double? get totalDeg => (azDeg == null || altDeg == null) ? null : math.sqrt(azDeg! * azDeg! + altDeg! * altDeg!);

  bool get onTarget => (totalDeg ?? 99) <= 3;
  bool get locked => (totalDeg ?? 99) <= 1;

  static PointerDelta from({required double targetAz, required double targetAlt, double? heading, double? pitch}) =>
      PointerDelta(
        azDeg: heading == null ? null : norm180(targetAz - heading),
        altDeg: pitch == null ? null : targetAlt - pitch,
      );
}

/// Lets the pointer screen fire haptics once per zone change, not per frame.
class HapticZone {
  int _zone = 0;

  /// Returns the zone just entered (2 locked, 1 close, 0 off), or null if unchanged.
  int? update(PointerDelta d) {
    final z = d.locked ? 2 : (d.onTarget ? 1 : 0);
    if (z == _zone) return null;
    _zone = z;
    return z;
  }
}
