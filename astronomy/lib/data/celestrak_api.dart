import 'package:dio/dio.dart';

import '../astro/orbit.dart';
import 'n2yo_api.dart' show SatErrorKind, SatException;

/// Published orbital elements for one satellite (CelesTrak GP data, OMM JSON).
class OrbitElements {
  const OrbitElements({
    required this.noradId,
    required this.name,
    required this.epoch,
    required this.meanMotionRevPerDay,
    required this.eccentricity,
    required this.inclinationDeg,
  });

  final int noradId;
  final String name;

  /// When these elements were measured (UTC).
  final DateTime epoch;
  final double meanMotionRevPerDay;
  final double eccentricity;
  final double inclinationDeg;

  double get periodMin => periodMinutes(meanMotionRevPerDay);
  ({double perigeeKm, double apogeeKm}) get heights => apsisHeightsKm(meanMotionRevPerDay, eccentricity);

  /// Mean of perigee and apogee, km.
  double get meanHeightKm => (heights.perigeeKm + heights.apogeeKm) / 2;

  factory OrbitElements.fromJson(Map<String, dynamic> j) => OrbitElements(
        noradId: (j['NORAD_CAT_ID'] as num).toInt(),
        name: j['OBJECT_NAME'] as String? ?? '',
        // CelesTrak epochs have no zone suffix but are UTC.
        epoch: DateTime.parse('${j['EPOCH']}Z'),
        meanMotionRevPerDay: (j['MEAN_MOTION'] as num).toDouble(),
        eccentricity: (j['ECCENTRICITY'] as num).toDouble(),
        inclinationDeg: (j['INCLINATION'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'NORAD_CAT_ID': noradId,
        'OBJECT_NAME': name,
        'EPOCH': epoch.toIso8601String().replaceAll('Z', ''),
        'MEAN_MOTION': meanMotionRevPerDay,
        'ECCENTRICITY': eccentricity,
        'INCLINATION': inclinationDeg,
      };
}

/// Client for CelesTrak GP data (https://celestrak.org/NORAD/documentation/gp-data-formats.php).
///
/// No key needed, and it allows browser requests. CelesTrak asks clients not
/// to download the same data more than once every two hours; the repository
/// caches it for longer than that.
class CelestrakApi {
  CelestrakApi(this._dio);

  final Dio _dio;

  Future<OrbitElements> elements(int noradId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://celestrak.org/NORAD/elements/gp.php',
        queryParameters: {'CATNR': noradId, 'FORMAT': 'json'},
      );
      final list = res.data ?? const [];
      if (list.isEmpty) throw SatException(SatErrorKind.api, 'No elements for $noradId');
      return OrbitElements.fromJson(list.first as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw SatException(status == null ? SatErrorKind.offline : SatErrorKind.api, status == null ? null : 'HTTP $status');
    }
  }
}
