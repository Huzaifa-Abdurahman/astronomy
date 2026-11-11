import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../astro/models.dart';
import '../../astro/orbit.dart';
import '../../core/env.dart';
import '../../data/celestrak_api.dart';
import '../../data/location_service.dart';
import '../../data/n2yo_api.dart';
import '../../data/place_service.dart' show dioProvider;
import '../../data/prefs.dart';

/// A satellite the app follows.
class Satellite {
  const Satellite({required this.noradId, required this.name, required this.kind});

  final int noradId;
  final String name;

  /// Short description, e.g. "Crewed station".
  final String kind;
}

/// Default satellites (CLAUDE.md §9). The first one is featured on open.
const defaultSatellites = [
  Satellite(noradId: 25544, name: 'ISS', kind: 'International Space Station · crewed'),
  Satellite(noradId: 48274, name: 'Tiangong', kind: 'Chinese Space Station · crewed'),
  Satellite(noradId: 20580, name: 'Hubble', kind: 'Space telescope'),
];

Satellite satelliteById(int id) => defaultSatellites.firstWhere((s) => s.noradId == id);

// ---------------------------------------------------------------------------
// API clients
// ---------------------------------------------------------------------------

final n2yoApiProvider = Provider<N2yoApi>((ref) => N2yoApi(ref.watch(dioProvider), Env.n2yoApiKey));
final celestrakApiProvider = Provider<CelestrakApi>((ref) => CelestrakApi(ref.watch(dioProvider)));

/// Riverpod retries failed providers by default. Each N2YO call counts toward
/// the hourly limit, so failures are shown instead of retried.
Duration? _noRetry(int count, Object error) => null;

// ---------------------------------------------------------------------------
// Selection and a 1 s clock for smooth movement
// ---------------------------------------------------------------------------

class SelectedSatellite extends Notifier<int> {
  @override
  int build() => defaultSatellites.first.noradId;

  void select(int noradId) => state = noradId;
}

final selectedSatelliteProvider = NotifierProvider<SelectedSatellite, int>(SelectedSatellite.new);

/// Wall-clock time each second. Satellites use the real clock, not the
/// mockable `clockProvider`, because N2YO always answers for the real "now".
final satClockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now().toUtc()),
);

// ---------------------------------------------------------------------------
// Live position (N2YO `positions`)
// ---------------------------------------------------------------------------

/// The latest batch of 1 s position samples, plus the last error if any.
class SatTrack {
  const SatTrack({this.samples = const [], this.error});

  final List<SatSample> samples;
  final SatException? error;

  bool get hasData => samples.isNotEmpty;

  /// Interpolated position at [now], or null before the first batch.
  SatSample? at(DateTime now) => sampleAt(samples, now);

  /// True while [now] is inside (or just past) the sampled range.
  bool isLive(DateTime now) => hasData && now.difference(samples.last.time).inSeconds < 5;
}

/// Seconds between polls. Each poll asks for that many 1 s samples (+2 s
/// overlap), so the track never runs dry between calls.
///
/// Budget: 3600/20 + 2 × 3600/60 = 300 position calls per hour, well inside
/// N2YO's 1000/hour.
const featuredPollS = 20;
const backgroundPollS = 60;

final satTrackProvider = StreamProvider.autoDispose.family<SatTrack, int>((ref, noradId) {
  final observer = ref.watch(observerProvider);
  final api = ref.watch(n2yoApiProvider);
  final period = ref.watch(selectedSatelliteProvider) == noradId ? featuredPollS : backgroundPollS;

  final controller = StreamController<SatTrack>();
  Timer? timer;
  var last = const SatTrack();

  Future<void> poll(Observer o) async {
    try {
      last = SatTrack(samples: await api.positions(noradId, o, seconds: period + 2));
    } on SatException catch (e) {
      last = SatTrack(samples: last.samples, error: e);
      // These will not fix themselves, so stop spending requests on them.
      if (e.kind == SatErrorKind.noKey || e.kind == SatErrorKind.blockedInBrowser) timer?.cancel();
    }
    if (!controller.isClosed) controller.add(last);
  }

  if (observer == null) {
    controller.add(last);
  } else {
    timer = Timer.periodic(Duration(seconds: period), (_) => poll(observer));
    poll(observer);
  }
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

// ---------------------------------------------------------------------------
// Visible passes (N2YO `visualpasses`), cached for 1 h
// ---------------------------------------------------------------------------

const _passCacheTtl = Duration(hours: 1);

/// A cached answer is reused while the observer is within this distance.
const _passCacheRadiusKm = 25.0;

/// Upcoming visible passes over the next 5 days, soonest first.
final satPassesProvider = FutureProvider.autoDispose.family<List<SatPass>, int>(
  (ref, noradId) async {
    final observer = ref.watch(observerProvider);
    if (observer == null) return const [];
    final prefs = ref.read(sharedPreferencesProvider);
    final key = '${PrefKeys.satPassesPrefix}$noradId';
    final now = DateTime.now().toUtc();

    // Refresh when the cached answer expires, even if the screen stays open.
    final timer = Timer(_passCacheTtl, ref.invalidateSelf);
    ref.onDispose(timer.cancel);

    final cached = _readPassCache(prefs.getString(key), observer, now);
    if (cached != null) return _upcoming(cached, now);

    final passes = await ref.read(n2yoApiProvider).visualPasses(noradId, observer);
    await prefs.setString(
      key,
      jsonEncode({
        'lat': observer.latDeg,
        'lon': observer.lonDeg,
        'at': now.toIso8601String(),
        'passes': [for (final p in passes) p.toJson()],
      }),
    );
    return _upcoming(passes, now);
  },
  retry: _noRetry,
);

List<SatPass> _upcoming(List<SatPass> passes, DateTime now) =>
    passes.where((p) => p.end.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));

List<SatPass>? _readPassCache(String? raw, Observer o, DateTime now) {
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.parse(j['at'] as String);
    if (now.difference(at) > _passCacheTtl) return null;
    final km = haversineKm(o.latDeg, o.lonDeg, (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
    if (km > _passCacheRadiusKm) return null;
    return [for (final p in (j['passes'] as List).cast<Map<String, dynamic>>()) SatPass.fromJson(p)];
  } on Object {
    return null;
  }
}

/// Great-circle distance between two points, km (haversine formula).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

// ---------------------------------------------------------------------------
// Orbit elements (CelesTrak), cached for 6 h
// ---------------------------------------------------------------------------

const _elementsCacheTtl = Duration(hours: 6);

/// Inclination, period and height. Also the fallback when N2YO is unavailable.
final orbitElementsProvider = FutureProvider.family<OrbitElements, int>(
  (ref, noradId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = '${PrefKeys.satElementsPrefix}$noradId';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (DateTime.now().toUtc().difference(DateTime.parse(j['at'] as String)) < _elementsCacheTtl) {
          return OrbitElements.fromJson(j['elements'] as Map<String, dynamic>);
        }
      } on Object {
        // Corrupt cache: fall through and refetch.
      }
    }
    final elements = await ref.read(celestrakApiProvider).elements(noradId);
    await prefs.setString(
      key,
      jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'elements': elements.toJson()}),
    );
    return elements;
  },
  retry: _noRetry,
);
