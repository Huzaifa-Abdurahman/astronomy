import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// User settings persisted in shared_preferences.
class AppSettings {
  const AppSettings({
    this.nightVision = false,
    this.alertsEnabled = true,
    this.precession = false,
    this.favourites = const {},
  });

  /// Red night-vision tint over the whole app.
  final bool nightVision;

  /// Pass and peak reminders.
  final bool alertsEnabled;

  /// Precess J2000 catalog coordinates to today's date (CLAUDE.md §6.9).
  final bool precession;

  /// Saved object ids.
  final Set<String> favourites;

  AppSettings copyWith({bool? nightVision, bool? alertsEnabled, bool? precession, Set<String>? favourites}) => AppSettings(
        nightVision: nightVision ?? this.nightVision,
        alertsEnabled: alertsEnabled ?? this.alertsEnabled,
        precession: precession ?? this.precession,
        favourites: favourites ?? this.favourites,
      );
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final p = ref.read(sharedPreferencesProvider);
    final favs = p.getString(PrefKeys.favourites);
    return AppSettings(
      nightVision: p.getBool(PrefKeys.nightVision) ?? false,
      alertsEnabled: p.getBool(PrefKeys.alertsEnabled) ?? true,
      precession: p.getBool(PrefKeys.precession) ?? false,
      favourites: favs == null ? const {} : (jsonDecode(favs) as List).cast<String>().toSet(),
    );
  }

  void setNightVision(bool v) {
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.nightVision, v);
    state = state.copyWith(nightVision: v);
  }

  void setAlerts(bool v) {
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.alertsEnabled, v);
    state = state.copyWith(alertsEnabled: v);
  }

  void setPrecession(bool v) {
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.precession, v);
    state = state.copyWith(precession: v);
  }

  void toggleFavourite(String id) {
    final next = {...state.favourites};
    if (!next.remove(id)) next.add(id);
    ref.read(sharedPreferencesProvider).setString(PrefKeys.favourites, jsonEncode(next.toList()));
    state = state.copyWith(favourites: next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
