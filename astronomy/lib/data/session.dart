import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'prefs.dart';
import 'profile_repository.dart';

/// Who is signed in: a Firebase user, or the local test user.
///
/// The test login exists for the testing phase only. It needs no Firebase
/// setup and no network: the profile lives in shared_preferences on this
/// device. It is only offered in debug builds ([testLoginAvailable]).
enum SessionKind { firebase, test }

class Session {
  const Session({required this.kind, required this.uid, required this.email, this.displayName, this.providerLabel});

  factory Session.firebase(User u) => Session(
        kind: SessionKind.firebase,
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        providerLabel: u.providerData.any((p) => p.providerId == 'google.com') ? 'Google' : 'Email',
      );

  static const test = Session(
    kind: SessionKind.test,
    uid: 'local-test-user',
    email: 'tester@skyguide.local',
    displayName: 'Test Explorer',
    providerLabel: 'Test',
  );

  final SessionKind kind;
  final String uid;
  final String? email;
  final String? displayName;
  final String? providerLabel;

  bool get isTest => kind == SessionKind.test;
}

/// The test button is shown only in debug builds, so it never ships in a
/// release APK.
const bool testLoginAvailable = kDebugMode;

/// Whether the local test user is signed in (persisted across restarts).
class TestLogin extends Notifier<bool> {
  @override
  bool build() => testLoginAvailable && (ref.read(sharedPreferencesProvider).getBool(PrefKeys.testLogin) ?? false);

  void signIn() {
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.testLogin, true);
    state = true;
  }

  void signOut() {
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.testLogin, false);
    state = false;
  }
}

final testLoginProvider = NotifierProvider<TestLogin, bool>(TestLogin.new);

/// The current session. A real Firebase user always wins over the test user.
final sessionProvider = Provider<Session?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user != null) return Session.firebase(user);
  return ref.watch(testLoginProvider) ? Session.test : null;
});

/// Name, avatar and home spot of the local test user, stored on the device.
class TestProfile extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final raw = ref.read(sharedPreferencesProvider).getString(PrefKeys.testProfile);
    if (raw == null) return const UserProfile(displayName: 'Test Explorer');
    try {
      return UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const UserProfile(displayName: 'Test Explorer');
    }
  }

  void _save(UserProfile p) {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.testProfile,
          jsonEncode({'displayName': p.displayName, 'avatar': p.avatar, 'home': p.home?.toMap()}),
        );
    state = p;
  }

  UserProfile _with({String? displayName, String? avatar, HomeSpot? home, bool clearHome = false}) => UserProfile(
        displayName: displayName ?? state.displayName,
        avatar: avatar ?? state.avatar,
        home: clearHome ? null : (home ?? state.home),
      );

  void setDisplayName(String name) => _save(_with(displayName: name.trim()));
  void setAvatar(String avatar) => _save(_with(avatar: avatar));
  void setHome(HomeSpot? home) => _save(_with(home: home, clearHome: home == null));
}

final testProfileProvider = NotifierProvider<TestProfile, UserProfile>(TestProfile.new);

/// The profile for whoever is signed in: Firestore for a real user, the
/// local store for the test user, null when signed out.
final sessionProfileProvider = Provider<UserProfile?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  if (session.isTest) return ref.watch(testProfileProvider);
  return ref.watch(userProfileProvider).value;
});

/// Profile edits, routed to Firestore or the local test store.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  Session? get _session => _ref.read(sessionProvider);

  Future<void> setDisplayName(String name) async {
    final s = _session;
    if (s == null) return;
    if (s.isTest) return _ref.read(testProfileProvider.notifier).setDisplayName(name);
    await _ref.read(profileRepositoryProvider).setDisplayName(s.uid, name);
    await _ref.read(authServiceProvider).updateDisplayName(name);
  }

  Future<void> setAvatar(String avatar) async {
    final s = _session;
    if (s == null) return;
    if (s.isTest) return _ref.read(testProfileProvider.notifier).setAvatar(avatar);
    await _ref.read(profileRepositoryProvider).setAvatar(s.uid, avatar);
  }

  Future<void> setHome(HomeSpot? home) async {
    final s = _session;
    if (s == null) return;
    if (s.isTest) return _ref.read(testProfileProvider.notifier).setHome(home);
    await _ref.read(profileRepositoryProvider).setHome(s.uid, home);
  }

  Future<void> signOut() async {
    final s = _session;
    if (s == null) return;
    if (s.isTest) return _ref.read(testLoginProvider.notifier).signOut();
    await _ref.read(authServiceProvider).signOut();
  }
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
