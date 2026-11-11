import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'settings.dart';

/// A saved observing spot.
class HomeSpot {
  const HomeSpot({required this.lat, required this.lon, this.label});

  final double lat;
  final double lon;
  final String? label;

  Map<String, dynamic> toMap() => {'lat': lat, 'lon': lon, 'label': label};

  static HomeSpot? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'], lon = raw['lon'];
    if (lat is! num || lon is! num) return null;
    return HomeSpot(lat: lat.toDouble(), lon: lon.toDouble(), label: raw['label'] as String?);
  }
}

/// The signed-in user's profile document at `users/{uid}`.
///
/// Fields match `firestore.rules`: displayName, avatar, favourites, settings,
/// home, createdAt, updatedAt.
class UserProfile {
  const UserProfile({
    this.displayName,
    this.avatar = 'wave',
    this.favourites = const {},
    this.nightVision = false,
    this.alertsEnabled = true,
    this.precession = false,
    this.home,
  });

  final String? displayName;

  /// A [CosmoPose] name; the avatar is Cosmo in that pose.
  final String avatar;
  final Set<String> favourites;
  final bool nightVision;
  final bool alertsEnabled;
  final bool precession;
  final HomeSpot? home;

  factory UserProfile.fromMap(Map<String, dynamic> d) {
    final s = (d['settings'] as Map?) ?? const {};
    return UserProfile(
      displayName: d['displayName'] as String?,
      avatar: d['avatar'] as String? ?? 'wave',
      favourites: ((d['favourites'] as List?) ?? const []).whereType<String>().toSet(),
      nightVision: s['nightVision'] as bool? ?? false,
      alertsEnabled: s['alertsEnabled'] as bool? ?? true,
      precession: s['precession'] as bool? ?? false,
      home: HomeSpot.fromMap(d['home']),
    );
  }

  /// The parts that mirror the on-device [AppSettings].
  bool matches(AppSettings a) =>
      a.nightVision == nightVision &&
      a.alertsEnabled == alertsEnabled &&
      a.precession == precession &&
      setEquals(a.favourites, favourites);
}

Map<String, dynamic> _settingsMap(AppSettings s) =>
    {'nightVision': s.nightVision, 'alertsEnabled': s.alertsEnabled, 'precession': s.precession};

class ProfileRepository {
  ProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  /// Live profile; null until the document exists.
  Stream<UserProfile?> watch(String uid) =>
      _doc(uid).snapshots().map((s) => s.exists ? UserProfile.fromMap(s.data()!) : null);

  /// First sign-in creates the document from what is on the device. Later
  /// sign-ins merge the device's saved objects into the profile, so nothing
  /// saved while signed out is lost.
  Future<void> ensureProfile(User user, AppSettings local) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': user.displayName ?? user.email?.split('@').first ?? 'Explorer',
        'avatar': 'wave',
        'favourites': local.favourites.toList(),
        'settings': _settingsMap(local),
        'home': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (local.favourites.isNotEmpty) {
      await ref.update({
        'favourites': FieldValue.arrayUnion(local.favourites.toList()),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> saveSettings(String uid, AppSettings s) => _doc(uid).set({
        'favourites': s.favourites.toList(),
        'settings': _settingsMap(s),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setDisplayName(String uid, String name) =>
      _doc(uid).set({'displayName': name.trim(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> setAvatar(String uid, String avatar) =>
      _doc(uid).set({'avatar': avatar, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> setHome(String uid, HomeSpot? home) =>
      _doc(uid).set({'home': home?.toMap(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(FirebaseFirestore.instance));

/// The signed-in user's id, or null.
final authUidProvider = Provider<String?>((ref) => ref.watch(authUserProvider.select((u) => u.value?.uid)));

/// The signed-in user's profile document (null when signed out or not created yet).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(authUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(uid);
});

/// Keeps on-device settings and the Firestore profile in step while signed in.
///
/// * Remote changes (another device) are applied to local settings.
/// * Local changes are written back, debounced, unless they came from remote.
///
/// Watched once from the app root.
final profileSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authUidProvider);
  if (uid == null) return;
  final repo = ref.read(profileRepositoryProvider);
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user != null) unawaited(repo.ensureProfile(user, ref.read(settingsProvider)).catchError((Object _) {}));

  UserProfile? lastRemote;
  Timer? debounce;
  ref.onDispose(() => debounce?.cancel());

  ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (_, next) {
    final remote = next.value;
    if (remote == null) return;
    lastRemote = remote;
    if (!remote.matches(ref.read(settingsProvider))) {
      ref.read(settingsProvider.notifier).applyRemote(
            nightVision: remote.nightVision,
            alertsEnabled: remote.alertsEnabled,
            precession: remote.precession,
            favourites: remote.favourites,
          );
    }
  });

  ref.listen<AppSettings>(settingsProvider, (_, next) {
    if (lastRemote?.matches(next) ?? false) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 600), () {
      repo.saveSettings(uid, ref.read(settingsProvider)).catchError((Object _) {});
    });
  });
});
