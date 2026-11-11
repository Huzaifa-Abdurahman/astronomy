import 'package:astronomy/data/profile_repository.dart';
import 'package:astronomy/data/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile document parses with defaults for missing fields', () {
    final p = UserProfile.fromMap({'displayName': 'Huzaifa'});
    expect(p.displayName, 'Huzaifa');
    expect(p.avatar, 'wave');
    expect(p.favourites, isEmpty);
    expect(p.alertsEnabled, isTrue);
    expect(p.home, isNull);
  });

  test('profile document parses settings, favourites and home', () {
    final p = UserProfile.fromMap({
      'avatar': 'telescope',
      'favourites': ['m31', 'vega', 42],
      'settings': {'nightVision': true, 'alertsEnabled': false, 'precession': true},
      'home': {'lat': 33.6844, 'lon': 73.0479, 'label': 'Islamabad'},
    });
    expect(p.avatar, 'telescope');
    expect(p.favourites, {'m31', 'vega'}); // non-strings ignored
    expect(p.nightVision, isTrue);
    expect(p.home?.label, 'Islamabad');
    expect(p.home?.lat, 33.6844);
  });

  test('a malformed home is ignored', () {
    expect(UserProfile.fromMap({'home': {'lat': 'x'}}).home, isNull);
  });

  test('matches compares only the synced settings', () {
    const p = UserProfile(favourites: {'m31'}, nightVision: true);
    expect(p.matches(const AppSettings(favourites: {'m31'}, nightVision: true)), isTrue);
    expect(p.matches(const AppSettings(favourites: {'m31', 'm42'}, nightVision: true)), isFalse);
    expect(p.matches(const AppSettings(favourites: {'m31'})), isFalse);
  });
}
