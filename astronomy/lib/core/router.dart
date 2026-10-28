import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/prefs.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/math/math_screen.dart';
import '../features/nearby/nearby_screen.dart';
import '../features/object_detail/object_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/permission/permission_screen.dart';
import '../features/pointer/pointer_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/satellites/satellites_screen.dart';
import '../features/tonight/tonight_screen.dart';
import 'widgets/sky_nav_bar.dart';

/// Route paths (CLAUDE.md §5).
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const permission = '/permission';
  static const home = '/home';
  static const explore = '/explore';
  static const nearby = '/nearby';
  static const satellites = '/satellites';
  static const profile = '/profile';
  static const tonight = '/tonight';
  static String object(String id) => '/object/$id';
  static String point(String id) => '/object/$id/point';
  static String math(String id) => '/object/$id/math';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    // Onboarding shows only on first launch.
    redirect: (context, state) {
      final done = prefs.getBool(PrefKeys.onboardingDone) ?? false;
      final atIntro = state.matchedLocation == Routes.onboarding || state.matchedLocation == Routes.permission;
      if (!done && !atIntro) return Routes.onboarding;
      return null;
    },
    routes: [
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.permission, builder: (_, _) => const PermissionScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.explore,
              builder: (_, state) => ExploreScreen(initialFilter: state.uri.queryParameters['type']),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.nearby, builder: (_, _) => const NearbyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.satellites, builder: (_, _) => const SatellitesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      // Pushed routes sit above the shell, so they have no bottom bar.
      GoRoute(
        path: Routes.tonight,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const TonightScreen(),
      ),
      GoRoute(
        path: '/object/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ObjectDetailScreen(objectId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'point',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => PointerScreen(objectId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'math',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => MathScreen(objectId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SkyNavBar(
        currentIndex: shell.currentIndex,
        // Tapping the active tab returns that tab to its first page.
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
