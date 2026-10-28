import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in `main()` and injected with an override, so every provider
/// can read preferences synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

/// Preference keys in one place.
abstract final class PrefKeys {
  static const onboardingDone = 'onboarding_done';
  static const lastLocation = 'last_location';
  static const manualLocation = 'manual_location';
  static const useManualLocation = 'use_manual_location';
  static const favourites = 'favourites';
  static const nightVision = 'night_vision';
  static const alertsEnabled = 'alerts_enabled';
  static const precession = 'precession';
  static const reminders = 'reminders';
}
