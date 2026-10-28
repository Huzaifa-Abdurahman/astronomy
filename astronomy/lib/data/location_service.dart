import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../astro/models.dart';
import 'place_service.dart';
import 'prefs.dart';

enum LocationSource { gps, manual, cached }

/// A resolved position plus where it came from and a display label.
class UserLocation {
  const UserLocation({required this.observer, required this.source, required this.fixedAt, this.label});

  final Observer observer;
  final LocationSource source;
  final DateTime fixedAt;

  /// City name when known; the UI falls back to coordinates.
  final String? label;

  String get displayLabel => label ?? formatCoords(observer.latDeg, observer.lonDeg);

  UserLocation copyWith({String? label, LocationSource? source}) =>
      UserLocation(observer: observer, source: source ?? this.source, fixedAt: fixedAt, label: label ?? this.label);

  Map<String, dynamic> toJson() => {
        'lat': observer.latDeg,
        'lon': observer.lonDeg,
        'alt': observer.altitudeM,
        'at': fixedAt.toIso8601String(),
        'label': label,
      };

  static UserLocation? fromJson(String? raw, LocationSource source) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return UserLocation(
        observer: Observer(
          latDeg: (j['lat'] as num).toDouble(),
          lonDeg: (j['lon'] as num).toDouble(),
          altitudeM: (j['alt'] as num?)?.toDouble() ?? 0,
        ),
        source: source,
        fixedAt: DateTime.parse(j['at'] as String),
        label: j['label'] as String?,
      );
    } on Object {
      return null;
    }
  }
}

String formatCoords(double lat, double lon) =>
    '${lat.abs().toStringAsFixed(2)}° ${lat >= 0 ? 'N' : 'S'}, ${lon.abs().toStringAsFixed(2)}° ${lon >= 0 ? 'E' : 'W'}';

enum LocationStatus { idle, locating, ready, denied, deniedForever, serviceDisabled, error }

class LocationState {
  const LocationState({required this.status, this.location});

  final LocationStatus status;

  /// The best known location; may be present while [status] is not ready
  /// (e.g. a cached fix while a fresh GPS fix is pending).
  final UserLocation? location;

  bool get hasLocation => location != null;
}

/// Live GPS location with a cached fallback and a manual override (CLAUDE.md §8).
class LocationController extends Notifier<LocationState> {
  StreamSubscription<Position>? _sub;

  @override
  LocationState build() {
    ref.onDispose(() => _sub?.cancel());
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(PrefKeys.useManualLocation) ?? false) {
      final manual = UserLocation.fromJson(prefs.getString(PrefKeys.manualLocation), LocationSource.manual);
      if (manual != null) return LocationState(status: LocationStatus.ready, location: manual);
    }
    final cached = UserLocation.fromJson(prefs.getString(PrefKeys.lastLocation), LocationSource.cached);
    // Resume GPS quietly if permission was granted earlier.
    Future.microtask(_resumeIfPermitted);
    return LocationState(status: cached == null ? LocationStatus.idle : LocationStatus.ready, location: cached);
  }

  bool get _manualMode => ref.read(sharedPreferencesProvider).getBool(PrefKeys.useManualLocation) ?? false;

  Future<void> _resumeIfPermitted() async {
    if (_manualMode) return;
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.whileInUse || p == LocationPermission.always) await _startGps();
  }

  /// Asks for permission (Permission screen) and starts GPS when granted.
  Future<LocationStatus> requestPermission() async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.useManualLocation, false);
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = LocationState(status: LocationStatus.serviceDisabled, location: state.location);
      return state.status;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) {
      state = LocationState(status: LocationStatus.deniedForever, location: state.location);
    } else if (p == LocationPermission.denied || p == LocationPermission.unableToDetermine) {
      state = LocationState(status: LocationStatus.denied, location: state.location);
    } else {
      await _startGps();
    }
    return state.status;
  }

  /// On Android, declining Google's "Location Accuracy" prompt makes the fused
  /// provider report the service as disabled even though GPS is on. In that
  /// case we fall back to the platform LocationManager.
  bool _useLocationManager = false;

  LocationSettings _settings({Duration? timeLimit, int distanceFilter = 0}) => _useLocationManager
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
          forceLocationManager: true,
        )
      : LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter, timeLimit: timeLimit);

  Future<void> _startGps() async {
    state = LocationState(status: LocationStatus.locating, location: state.location);
    try {
      final first = await Geolocator.getCurrentPosition(locationSettings: _settings(timeLimit: const Duration(seconds: 20)));
      _apply(first);
      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(locationSettings: _settings(distanceFilter: 100)).listen(_apply, onError: (_) {});
    } on LocationServiceDisabledException {
      if (!_useLocationManager && await Geolocator.isLocationServiceEnabled()) {
        _useLocationManager = true;
        return _startGps();
      }
      state = LocationState(status: LocationStatus.serviceDisabled, location: state.location);
    } on Object {
      state = LocationState(
        status: state.location == null ? LocationStatus.error : LocationStatus.ready,
        location: state.location,
      );
    }
  }

  void _apply(Position p) {
    if (_manualMode) return;
    final previous = state.location;
    final loc = UserLocation(
      observer: Observer(latDeg: p.latitude, lonDeg: p.longitude, altitudeM: p.altitude),
      source: LocationSource.gps,
      fixedAt: p.timestamp.toUtc(),
      // Keep the old city name while it is still roughly the same place.
      label: previous != null && _distanceKm(previous.observer, p) < 15 ? previous.label : null,
    );
    state = LocationState(status: LocationStatus.ready, location: loc);
    _save(loc);
    if (loc.label == null) _lookupLabel(loc);
  }

  Future<void> _lookupLabel(UserLocation loc) async {
    final name = await ref.read(placeServiceProvider).cityName(loc.observer.latDeg, loc.observer.lonDeg);
    if (name == null || state.location?.fixedAt != loc.fixedAt) return;
    final named = loc.copyWith(label: name);
    state = LocationState(status: state.status, location: named);
    _save(named);
  }

  void _save(UserLocation loc) =>
      ref.read(sharedPreferencesProvider).setString(PrefKeys.lastLocation, jsonEncode(loc.toJson()));

  /// Manual override: a searched city or typed coordinates.
  Future<void> setManual(Observer observer, {String? label}) async {
    await _sub?.cancel();
    _sub = null;
    final loc = UserLocation(observer: observer, source: LocationSource.manual, fixedAt: DateTime.now().toUtc(), label: label);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.manualLocation, jsonEncode(loc.toJson()));
    await prefs.setBool(PrefKeys.useManualLocation, true);
    state = LocationState(status: LocationStatus.ready, location: loc);
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static double _distanceKm(Observer a, Position b) =>
      Geolocator.distanceBetween(a.latDeg, a.lonDeg, b.latitude, b.longitude) / 1000;
}

final locationProvider = NotifierProvider<LocationController, LocationState>(LocationController.new);

/// The observer used by every astronomy calculation, or null with no location.
final observerProvider = Provider<Observer?>((ref) => ref.watch(locationProvider.select((s) => s.location?.observer)));
