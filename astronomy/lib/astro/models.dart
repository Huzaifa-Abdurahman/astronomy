/// Plain data types shared by the astro engine and the UI. No Flutter imports.
library;

import 'angles.dart';

enum SkyObjectType {
  star,
  planet,
  galaxy,
  nebula,
  cluster;

  static SkyObjectType parse(String s) => SkyObjectType.values.byName(s);
}

/// A catalog entry (CLAUDE.md §7). Coordinates are J2000.
///
/// Solar-system bodies (`type == planet`, plus the Sun and Moon) have no fixed
/// coordinates; [raDeg]/[decDeg] are null and positions come from `planets.dart`.
class SkyObject {
  const SkyObject({
    required this.id,
    required this.name,
    required this.catalog,
    required this.type,
    required this.raDeg,
    required this.decDeg,
    required this.mag,
    this.subtype,
    this.altId,
    this.constellation,
    this.distance,
    this.image,
    this.summary,
  });

  final String id;
  final String name;
  final String catalog;
  final SkyObjectType type;
  final double? raDeg;
  final double? decDeg;
  final double? mag;

  /// Finer description, e.g. "spiral galaxy", "globular cluster".
  final String? subtype;

  /// Cross-identification, e.g. "NGC 224" for M31.
  final String? altId;
  final String? constellation;
  final String? distance;
  final String? image;
  final String? summary;

  bool get isSolarSystem => raDeg == null || decDeg == null;

  factory SkyObject.fromJson(Map<String, dynamic> j) => SkyObject(
        id: j['id'] as String,
        name: j['name'] as String,
        catalog: j['catalog'] as String,
        type: SkyObjectType.parse(j['type'] as String),
        raDeg: (j['raDeg'] as num?)?.toDouble(),
        decDeg: (j['decDeg'] as num?)?.toDouble(),
        mag: (j['mag'] as num?)?.toDouble(),
        subtype: j['subtype'] as String?,
        altId: j['altId'] as String?,
        constellation: j['constellation'] as String?,
        distance: j['distance'] as String?,
        image: j['image'] as String?,
        summary: j['summary'] as String?,
      );
}

/// Where the user is standing. Longitude is east-positive.
class Observer {
  const Observer({required this.latDeg, required this.lonDeg, this.altitudeM = 0});

  final double latDeg;
  final double lonDeg;
  final double altitudeM;

  @override
  bool operator ==(Object other) =>
      other is Observer && other.latDeg == latDeg && other.lonDeg == lonDeg && other.altitudeM == altitudeM;

  @override
  int get hashCode => Object.hash(latDeg, lonDeg, altitudeM);

  @override
  String toString() => 'Observer($latDeg, $lonDeg, ${altitudeM}m)';
}

/// Right ascension / declination, both in degrees.
class Equatorial {
  const Equatorial(this.raDeg, this.decDeg);

  final double raDeg;
  final double decDeg;

  @override
  String toString() => 'Equatorial(ra: ${raDeg.toStringAsFixed(4)}, dec: ${decDeg.toStringAsFixed(4)})';
}

/// Altitude above the horizon and azimuth from north, clockwise (degrees).
class HorizontalPosition {
  const HorizontalPosition({required this.altDeg, required this.azDeg, required this.hourAngleDeg});

  final double altDeg;
  final double azDeg;

  /// The hour angle used to compute this position, −180…180.
  final double hourAngleDeg;

  String get compass => compass16(azDeg);
  bool get isUp => altDeg > 0;
}

enum RiseSetKind {
  /// Rises and sets normally.
  normal,

  /// Never sets from this latitude.
  circumpolar,

  /// Never rises from this latitude.
  neverRises,
}

/// Rise, transit (culmination) and set around a reference time (UTC).
class RiseTransitSet {
  const RiseTransitSet({
    required this.kind,
    required this.transit,
    required this.transitAltDeg,
    required this.transitAzDeg,
    this.rise,
    this.set,
    this.riseAzDeg,
    this.setAzDeg,
    this.h0HourAngleDeg,
  });

  final RiseSetKind kind;
  final DateTime transit;
  final double transitAltDeg;
  final double transitAzDeg;

  /// Null unless [kind] is [RiseSetKind.normal].
  final DateTime? rise;
  final DateTime? set;
  final double? riseAzDeg;
  final double? setAzDeg;

  /// Semi-diurnal arc H0 in degrees (null when it does not exist).
  final double? h0HourAngleDeg;
}

/// A span of time (UTC) with the best moment inside it.
class VisibilityWindow {
  const VisibilityWindow({required this.start, required this.end, required this.peak, required this.peakAltDeg});

  final DateTime start;
  final DateTime end;
  final DateTime peak;
  final double peakAltDeg;

  Duration get duration => end.difference(start);
  bool contains(DateTime t) => !t.isBefore(start) && !t.isAfter(end);
}

/// One sample of an altitude-vs-time curve.
class AltitudeSample {
  const AltitudeSample(this.time, this.altDeg);

  final DateTime time;
  final double altDeg;
}
