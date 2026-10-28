import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A named place returned by city search.
class Place {
  const Place({required this.name, required this.lat, required this.lon, this.region, this.country, this.elevationM});

  final String name;
  final double lat;
  final double lon;
  final String? region;
  final String? country;
  final double? elevationM;

  String get subtitle => [region, country].whereType<String>().where((s) => s.isNotEmpty).join(', ');
}

/// City search and reverse lookup using free, key-less public APIs.
///
/// * Search: Open-Meteo Geocoding API (https://open-meteo.com/en/docs/geocoding-api)
/// * Reverse: BigDataCloud client-side reverse geocoding
///   (https://www.bigdatacloud.com/free-api/free-reverse-geocode-to-city-api)
///
/// Both are optional niceties: every caller falls back to coordinates.
class PlaceService {
  PlaceService(this._dio);

  final Dio _dio;

  Future<List<Place>> search(String query) async {
    if (query.trim().length < 2) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {'name': query.trim(), 'count': 8, 'language': 'en', 'format': 'json'},
    );
    final results = (res.data?['results'] as List?) ?? const [];
    return [
      for (final r in results.cast<Map<String, dynamic>>())
        Place(
          name: r['name'] as String,
          lat: (r['latitude'] as num).toDouble(),
          lon: (r['longitude'] as num).toDouble(),
          region: r['admin1'] as String?,
          country: r['country'] as String?,
          elevationM: (r['elevation'] as num?)?.toDouble(),
        ),
    ];
  }

  /// Nearest city name for a coordinate, or null if unavailable.
  Future<String?> cityName(double lat, double lon) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {'latitude': lat, 'longitude': lon, 'localityLanguage': 'en'},
      );
      final d = res.data;
      final name = (d?['city'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
      final locality = (d?['locality'] as String?)?.trim();
      return (locality == null || locality.isEmpty) ? null : locality;
    } on DioException {
      return null;
    }
  }
}

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    )));

final placeServiceProvider = Provider<PlaceService>((ref) => PlaceService(ref.watch(dioProvider)));
