/// Time scales: Julian Date, days since J2000, sidereal time.
///
/// Every function takes a [DateTime] and converts it to UTC first, so callers
/// can never accidentally feed local time into the math.
library;

import 'angles.dart';

/// Julian Date of the Unix epoch (1970-01-01T00:00Z).
const double jdUnixEpoch = 2440587.5;

/// Julian Date of the J2000.0 epoch (2000-01-01T12:00 TT, used here as UT).
const double jdJ2000 = 2451545.0;

/// Sidereal days are shorter than solar days: 1 solar hour = 1.0027379
/// sidereal hours. Divide sidereal/hour-angle hours by this to get clock hours.
const double siderealRatio = 1.0027379;

/// Julian Date (CLAUDE.md §6.1): `JD = unixMillis / 86400000 + 2440587.5`.
///
/// Source: Meeus, *Astronomical Algorithms*, 2nd ed., ch. 7.
double julianDate(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000.0 + jdUnixEpoch;

/// Converts a Julian Date back to a UTC [DateTime].
DateTime dateTimeFromJulian(double jd) =>
    DateTime.fromMillisecondsSinceEpoch(((jd - jdUnixEpoch) * 86400000.0).round(), isUtc: true);

/// Days since J2000.0 (CLAUDE.md §6.2): `D = JD − 2451545.0`.
double daysSinceJ2000(DateTime t) => julianDate(t) - jdJ2000;

/// Greenwich Mean Sidereal Time in degrees (CLAUDE.md §6.3):
/// `GMST = 280.46061837 + 360.98564736629 · D`, normalised to 0–360.
///
/// Source: Meeus ch. 12, eq. 12.4 (the small T² and T³ terms are omitted;
/// they amount to < 0.01° this century).
double gmstDeg(DateTime t) => norm360(280.46061837 + 360.98564736629 * daysSinceJ2000(t));

/// Local Sidereal Time in degrees (CLAUDE.md §6.4): `LST = GMST + λ`,
/// with longitude λ east-positive.
double lstDeg(DateTime t, double lonDeg) => norm360(gmstDeg(t) + lonDeg);

/// Adds a (possibly fractional, possibly negative) number of hours.
DateTime addHours(DateTime t, double hours) => t.add(Duration(microseconds: (hours * 3.6e9).round()));
