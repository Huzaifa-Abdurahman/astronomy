/// Angle helpers. All public astro APIs take and return **degrees**.
library;

import 'dart:math' as math;

const double degToRad = math.pi / 180;
const double radToDeg = 180 / math.pi;

double sinD(double deg) => math.sin(deg * degToRad);
double cosD(double deg) => math.cos(deg * degToRad);
double tanD(double deg) => math.tan(deg * degToRad);
double asinD(double x) => math.asin(x.clamp(-1.0, 1.0)) * radToDeg;
double acosD(double x) => math.acos(x.clamp(-1.0, 1.0)) * radToDeg;
double atan2D(double y, double x) => math.atan2(y, x) * radToDeg;

/// Normalises to 0 ≤ x < 360 using `((x % 360) + 360) % 360` (CLAUDE.md §6).
double norm360(double x) => ((x % 360) + 360) % 360;

/// Normalises to −180 < x ≤ 180.
double norm180(double x) {
  final n = norm360(x);
  return n > 180 ? n - 360 : n;
}

const _compass16 = [
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
];

/// 16-point compass label for an azimuth measured from north, clockwise.
/// Each sector is 22.5° wide and centred on its direction.
String compass16(double azDeg) => _compass16[((norm360(azDeg) + 11.25) ~/ 22.5) % 16];

/// Right ascension in degrees → "00h42m44s".
String formatRa(double raDeg) {
  final totalSeconds = (norm360(raDeg) / 15 * 3600).round();
  final h = totalSeconds ~/ 3600 % 24;
  final m = totalSeconds % 3600 ~/ 60;
  final s = totalSeconds % 60;
  return '${_two(h)}h${_two(m)}m${_two(s)}s';
}

/// Declination in degrees → "+41°16′09″".
String formatDec(double decDeg) {
  final sign = decDeg < 0 ? '−' : '+';
  final totalSeconds = (decDeg.abs() * 3600).round();
  final d = totalSeconds ~/ 3600;
  final m = totalSeconds % 3600 ~/ 60;
  final s = totalSeconds % 60;
  return '$sign${_two(d)}°${_two(m)}′${_two(s)}″';
}

String _two(int v) => v.toString().padLeft(2, '0');
