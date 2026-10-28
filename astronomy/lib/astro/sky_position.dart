/// One entry point from a [SkyObject] to its RA/Dec at any instant.
library;

import 'models.dart';
import 'planets.dart';
import 'precession.dart';
import 'rise_set.dart';
import 'sun.dart';

/// Ids of the solar-system bodies in the catalog.
abstract final class SolarSystemIds {
  static const sun = 'sun';
  static const moon = 'moon';
  static const planets = {
    'mercury': Planet.mercury,
    'venus': Planet.venus,
    'mars': Planet.mars,
    'jupiter': Planet.jupiter,
    'saturn': Planet.saturn,
    'uranus': Planet.uranus,
    'neptune': Planet.neptune,
  };
}

/// Builds the [PositionFn] for [object] as seen by [observer].
///
/// Catalog objects return their J2000 coordinates, optionally precessed to
/// the date when [precess] is on (CLAUDE.md §6.9). The Sun, Moon and planets
/// are computed for each instant.
PositionFn positionFnFor(SkyObject object, Observer observer, {bool precess = false}) {
  if (!object.isSolarSystem) {
    final j2000 = Equatorial(object.raDeg!, object.decDeg!);
    return precess ? (t) => precessFromJ2000(j2000, t) : (_) => j2000;
  }
  if (object.id == SolarSystemIds.sun) return sunPosition;
  if (object.id == SolarSystemIds.moon) return (t) => moonPosition(t, observer);
  final planet = SolarSystemIds.planets[object.id];
  if (planet == null) throw ArgumentError('No ephemeris for "${object.id}"');
  return (t) => planetPosition(planet, t);
}
