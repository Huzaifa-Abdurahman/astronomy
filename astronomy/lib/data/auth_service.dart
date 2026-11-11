import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Authentication: email/password and Google.
///
/// Google uses Firebase's own provider flow (`signInWithProvider` on
/// Android/iOS, a popup on the web), so no extra Google Sign-In package or
/// client-id wiring is needed. Android still needs the app's SHA-1/SHA-256
/// registered in the Firebase console.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  /// Creates the account and sets its display name.
  Future<void> registerWithEmail(String name, String email, String password) => _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          await cred.user?.updateDisplayName(trimmed);
          await cred.user?.reload();
        }
      });

  Future<void> signInWithGoogle() => _guard(() {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        return kIsWeb ? _auth.signInWithPopup(provider) : _auth.signInWithProvider(provider);
      });

  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> updateDisplayName(String name) => _guard(() async {
        await _auth.currentUser?.updateDisplayName(name.trim());
        await _auth.currentUser?.reload();
      });

  Future<void> signOut() => _auth.signOut();

  /// Runs [action] and turns Firebase errors into a readable [AuthFailure].
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthMessage(e.code, e.message));
    }
  }
}

/// A sign-in error with a message fit to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maps Firebase Auth error codes to plain sentences.
String friendlyAuthMessage(String code, [String? fallback]) => switch (code) {
      'invalid-email' => 'That email address does not look right.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account with this email already exists. Try signing in.',
      'weak-password' => 'Use a password with at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
      'network-request-failed' => 'No internet connection.',
      'operation-not-allowed' => 'This sign-in method is not enabled in the Firebase console yet.',
      'popup-closed-by-user' || 'web-context-canceled' || 'canceled' => 'Sign-in was cancelled.',
      'account-exists-with-different-credential' =>
        'This email is already registered with a different sign-in method. Use that one instead.',
      _ => fallback ?? 'Sign-in failed ($code).',
    };

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(firebaseAuthProvider)));

/// The signed-in user (null when signed out). `userChanges` also fires when
/// the display name changes, so the profile header updates immediately.
final authUserProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).userChanges());
