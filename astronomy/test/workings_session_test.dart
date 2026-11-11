import 'package:astronomy/astro/coords.dart';
import 'package:astronomy/astro/models.dart';
import 'package:astronomy/astro/workings.dart';
import 'package:astronomy/data/auth_service.dart';
import 'package:astronomy/data/prefs.dart';
import 'package:astronomy/data/profile_repository.dart';
import 'package:astronomy/data/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Math screen workings match CLAUDE.md §6.8', () {
    const islamabad = Observer(latDeg: 33.6844, lonDeg: 73.0479);
    final t = DateTime.utc(2026, 10, 28, 15);
    final w = computeWorkings(const Equatorial(10.6847, 41.2692), islamabad, t);

    test('steps 1–5', () {
      expect(w.jd, closeTo(2461342.125, 0.0001));
      expect(w.d, closeTo(9797.125, 0.0001));
      expect(w.gmst, closeTo(261.971, 0.01));
      expect(w.lst, closeTo(335.019, 0.01));
      expect(w.hourAngle, closeTo(-35.666, 0.01));
    });

    test('steps 6–7: altitude and azimuth (east of meridian, no flip)', () {
      expect(w.altDeg, closeTo(60.92, 0.05));
      expect(w.westOfMeridian, isFalse);
      expect(w.aRaw, closeTo(w.azDeg, 1e-9));
      expect(w.azDeg, closeTo(64.38, 0.1));
      expect(w.compass, 'ENE');
    });

    test('agrees exactly with the engine used by every other screen', () {
      final h = horizontalAt(const Equatorial(10.6847, 41.2692), islamabad, t);
      expect(w.altDeg, closeTo(h.altDeg, 1e-9));
      expect(w.azDeg, closeTo(h.azDeg, 1e-9));
    });

    test('rise/set: transit altitude and a normal rising object', () {
      expect(w.transitAltDeg, closeTo(82.4, 0.05));
      expect(w.circumpolar, isFalse);
      expect(w.neverRises, isFalse);
      expect(w.h0Deg, isNotNull);
    });

    test('Vega is west of the meridian, so A = 360° − A', () {
      final v = computeWorkings(const Equatorial(279.23, 38.78), islamabad, t);
      expect(v.westOfMeridian, isTrue);
      expect(v.azDeg, closeTo(360 - v.aRaw, 1e-9));
      expect(v.altDeg, closeTo(45.4, 0.1));
      expect(v.azDeg, closeTo(293, 0.5));
    });

    test('Polaris is circumpolar from Islamabad', () {
      final p = computeWorkings(const Equatorial(37.95, 89.26), islamabad, t);
      expect(p.circumpolar, isTrue);
      expect(p.h0Deg, isNull);
    });
  });

  group('test login', () {
    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authUserProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('signs in a local test user without Firebase', () async {
      final c = await container();
      expect(c.read(sessionProvider), isNull);
      c.read(testLoginProvider.notifier).signIn();
      final s = c.read(sessionProvider)!;
      expect(s.isTest, isTrue);
      expect(c.read(sessionProfileProvider)?.displayName, 'Test Explorer');
    });

    test('profile edits persist locally and sign-out clears the session', () async {
      final c = await container();
      c.read(testLoginProvider.notifier).signIn();
      final actions = c.read(profileActionsProvider);
      await actions.setDisplayName('Huzaifa');
      await actions.setAvatar('telescope');
      await actions.setHome(const HomeSpot(lat: 33.6844, lon: 73.0479, label: 'Islamabad'));
      final p = c.read(sessionProfileProvider)!;
      expect(p.displayName, 'Huzaifa');
      expect(p.avatar, 'telescope');
      expect(p.home?.label, 'Islamabad');

      // Survives a restart (a fresh notifier reading the same prefs).
      c.invalidate(testProfileProvider);
      expect(c.read(testProfileProvider).displayName, 'Huzaifa');

      await actions.signOut();
      expect(c.read(sessionProvider), isNull);
    });
  });
}
