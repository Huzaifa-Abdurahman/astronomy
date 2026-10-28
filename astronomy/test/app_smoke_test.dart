import 'dart:convert';

import 'package:astronomy/app.dart';
import 'package:astronomy/core/format.dart';
import 'package:astronomy/core/router.dart';
import 'package:astronomy/core/theme/app_text.dart';
import 'package:astronomy/data/catalog_repository.dart';
import 'package:astronomy/data/clock.dart';
import 'package:astronomy/data/prefs.dart';
import 'package:astronomy/features/explore/explore_controller.dart';
import 'package:astronomy/astro/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CLAUDE.md §6.8: Islamabad, 2026-10-28 15:00 UTC.
final testTime = DateTime.utc(2026, 10, 28, 15);

Future<ProviderContainer> bootAppForTest(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false; // fonts are bundled
  SharedPreferences.setMockInitialValues({
    PrefKeys.onboardingDone: true,
    PrefKeys.useManualLocation: true,
    PrefKeys.manualLocation: jsonEncode({
      'lat': 33.6844,
      'lon': 73.0479,
      'alt': 540,
      'at': testTime.toIso8601String(),
      'label': 'Islamabad',
    }),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), clockProvider.overrideWithValue(() => testTime)],
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.runAsync(() => container.read(catalogProvider.future));
  // Start loading every bundled font weight, then wait, so the first frame is
  // laid out with the real typefaces instead of the wide test font.
  for (final w in [FontWeight.w700, FontWeight.w800]) {
    AppText.display(10, weight: w);
  }
  for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    AppText.body(10, weight: w);
  }
  for (final w in [FontWeight.w400, FontWeight.w500]) {
    AppText.mono(10, weight: w);
  }
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SkyGuideApp()));
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> tearDownForTest(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  testWidgets('Home shows M31 matching the §6.8 test vector', (tester) async {
    final container = await bootAppForTest(tester);

    expect(find.text('Islamabad'), findsOneWidget);
    expect(find.text('Andromeda Galaxy'), findsOneWidget);
    // Peak is the transit, ≈ 22:22 PKT = 17:22 UTC (shown in device local time).
    final peak = formatClock(DateTime.utc(2026, 10, 28, 17, 22));
    expect(find.textContaining(peak, findRichText: true), findsWidgets);
    expect(find.textContaining('ENE 64°', findRichText: true), findsOneWidget);
    expect(find.textContaining('60.9° up', findRichText: true), findsOneWidget);

    await tearDownForTest(tester, container);
  });

  testWidgets('every route opens without errors', (tester) async {
    final container = await bootAppForTest(tester);
    final router = container.read(routerProvider);
    final routes = [
      Routes.home,
      Routes.explore,
      '${Routes.explore}?type=galaxy',
      Routes.nearby,
      Routes.satellites,
      Routes.profile,
      Routes.tonight,
      Routes.object('m31'),
      Routes.object('jupiter'),
      Routes.object('polaris'),
      Routes.point('m31'),
      Routes.math('m31'),
      Routes.onboarding,
      Routes.permission,
    ];
    for (final r in routes) {
      router.go(r);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // let draw-in animations finish
      expect(tester.takeException(), isNull, reason: 'route $r threw');
    }
    await tearDownForTest(tester, container);
  });

  testWidgets('Explore lists everything by default and filters by type', (tester) async {
    final container = await bootAppForTest(tester);
    final router = container.read(routerProvider);
    router.go(Routes.explore);
    await tester.pump(const Duration(seconds: 1));
    // 147 catalog objects; the Sun is not in the catalog.
    expect(container.read(exploreResultsProvider)?.length, 147);
    router.go('${Routes.explore}?type=galaxy');
    await tester.pump(const Duration(seconds: 1));
    final galaxies = container.read(exploreResultsProvider)!;
    expect(galaxies, isNotEmpty);
    expect(galaxies.every((i) => i.object.type == SkyObjectType.galaxy), isTrue);
    await tearDownForTest(tester, container);
  });
}
