import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../astro/models.dart';
import '../astro/orbit.dart';

/// Why a satellite request failed, so the UI can say something useful.
enum SatErrorKind {
  /// `N2YO_API_KEY` is missing from `.env`.
  noKey,

  /// Running in a browser: N2YO sends no CORS headers, so browsers block it.
  blockedInBrowser,

  /// No connection or a timeout.
  offline,

  /// N2YO answered with an error (bad key, hourly limit reached…).
  api,
}

class SatException implements Exception {
  const SatException(this.kind, [this.message]);

  final SatErrorKind kind;
  final String? message;

  @override
  String toString() => 'SatException($kind${message == null ? '' : ': $message'})';
}

/// One predicted visible pass (N2YO `visualpasses`).
class SatPass {
  const SatPass({
    required this.start,
    required this.max,
    required this.end,
    required this.startAzCompass,
    required this.maxAzCompass,
    required this.endAzCompass,
    required this.startEl,
    required this.maxEl,
    required this.durationS,
    this.startAz = 0,
    this.maxAz = 0,
    this.endAz = 0,
    this.endEl = 0,
    this.mag,
  });

  final DateTime start;
  final DateTime max;
  final DateTime end;
  final String startAzCompass;
  final String maxAzCompass;
  final String endAzCompass;
  final double startEl;
  final double maxEl;

  /// Azimuths in degrees (N2YO also sends the compass points above).
  final double startAz;
  final double maxAz;
  final double endAz;
  final double endEl;

  /// Visible duration, seconds.
  final int durationS;

  /// Peak visual magnitude; null when N2YO cannot determine it (it sends 100000).
  final double? mag;

  /// "Appears WSW, climbs to 52°, gone NE after 4 min" (CLAUDE.md §9).
  String get pathText {
    final mins = (durationS / 60).round().clamp(1, 999);
    return 'Appears $startAzCompass, climbs to ${maxEl.round()}°, gone $endAzCompass after $mins min';
  }

  factory SatPass.fromJson(Map<String, dynamic> j) {
    DateTime t(String k) => DateTime.fromMillisecondsSinceEpoch((j[k] as num).toInt() * 1000, isUtc: true);
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final mag = (j['mag'] as num?)?.toDouble();
    return SatPass(
      start: t('startUTC'),
      max: t('maxUTC'),
      end: t('endUTC'),
      startAzCompass: j['startAzCompass'] as String? ?? '?',
      maxAzCompass: j['maxAzCompass'] as String? ?? '?',
      endAzCompass: j['endAzCompass'] as String? ?? '?',
      startEl: d('startEl'),
      maxEl: d('maxEl'),
      startAz: d('startAz'),
      maxAz: d('maxAz'),
      endAz: d('endAz'),
      endEl: d('endEl'),
      durationS: (j['duration'] as num?)?.toInt() ?? 0,
      mag: (mag == null || mag >= 100000) ? null : mag,
    );
  }

  Map<String, dynamic> toJson() => {
        'startUTC': start.millisecondsSinceEpoch ~/ 1000,
        'maxUTC': max.millisecondsSinceEpoch ~/ 1000,
        'endUTC': end.millisecondsSinceEpoch ~/ 1000,
        'startAzCompass': startAzCompass,
        'maxAzCompass': maxAzCompass,
        'endAzCompass': endAzCompass,
        'startEl': startEl,
        'maxEl': maxEl,
        'startAz': startAz,
        'maxAz': maxAz,
        'endAz': endAz,
        'endEl': endEl,
        'duration': durationS,
        'mag': mag ?? 100000,
      };
}

/// Client for the N2YO REST API v1 (https://www.n2yo.com/api/).
///
/// Hourly limits per key: positions 1000, visualpasses 100, tle 1000.
/// This class does no caching; see `satellites_repository.dart`.
class N2yoApi {
  N2yoApi(this._dio, this._apiKey);

  static const _base = 'https://api.n2yo.com/rest/v1/satellite';

  final Dio _dio;
  final String _apiKey;

  /// Observer path segment: lat/lng/altMeters.
  static String _where(Observer o) =>
      '${o.latDeg.toStringAsFixed(4)}/${o.lonDeg.toStringAsFixed(4)}/${o.altitudeM.isFinite ? o.altitudeM.round() : 0}';

  /// [seconds] future positions, one per second, starting now (max 300).
  Future<List<SatSample>> positions(int noradId, Observer o, {int seconds = 10}) async {
    final j = await _get('positions/$noradId/${_where(o)}/${seconds.clamp(1, 300)}');
    return parsePositions(j);
  }

  /// Visible passes over the next [days] (max 10), each visible at least [minVisibleS] seconds.
  Future<List<SatPass>> visualPasses(int noradId, Observer o, {int days = 5, int minVisibleS = 60}) async {
    final j = await _get('visualpasses/$noradId/${_where(o)}/${days.clamp(1, 10)}/$minVisibleS');
    final passes = (j['passes'] as List?) ?? const [];
    return [for (final p in passes.cast<Map<String, dynamic>>()) SatPass.fromJson(p)];
  }

  static List<SatSample> parsePositions(Map<String, dynamic> j) {
    final list = (j['positions'] as List?) ?? const [];
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        SatSample(
          time: DateTime.fromMillisecondsSinceEpoch((p['timestamp'] as num).toInt() * 1000, isUtc: true),
          latDeg: (p['satlatitude'] as num).toDouble(),
          lonDeg: (p['satlongitude'] as num).toDouble(),
          altKm: (p['sataltitude'] as num).toDouble(),
          azDeg: (p['azimuth'] as num).toDouble(),
          elDeg: (p['elevation'] as num).toDouble(),
        ),
    ];
  }

  Future<Map<String, dynamic>> _get(String path) async {
    if (_apiKey.isEmpty) throw const SatException(SatErrorKind.noKey);
    try {
      // N2YO expects the key appended as "&apiKey=" right after the path.
      final res = await _dio.get<Map<String, dynamic>>('$_base/$path/&apiKey=$_apiKey');
      final data = res.data ?? const {};
      final error = data['error'];
      if (error != null) throw SatException(SatErrorKind.api, '$error');
      return data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null) throw SatException(SatErrorKind.api, 'HTTP $status');
      // A browser reports a CORS block as a bare connection error.
      if (kIsWeb) throw const SatException(SatErrorKind.blockedInBrowser);
      throw const SatException(SatErrorKind.offline);
    }
  }
}
