import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now" (UTC). Mockable for tests and demos:
///
/// `flutter run --dart-define=SKYGUIDE_NOW=2026-10-28T15:00:00Z`
///
/// starts the app at that instant and lets time run forward from there, which
/// is how the CLAUDE.md §6.8 test vector can be checked on a device.
final clockProvider = Provider<DateTime Function()>((ref) {
  const fake = String.fromEnvironment('SKYGUIDE_NOW');
  if (fake.isEmpty) return () => DateTime.now().toUtc();
  final base = DateTime.parse(fake).toUtc();
  final startedAt = DateTime.now();
  return () => base.add(DateTime.now().difference(startedAt));
});

/// Current time, refreshed every 10 s (live readouts recalculate on this tick).
class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(const Duration(seconds: 10), (_) => state = clock());
    ref.onDispose(timer.cancel);
    return clock();
  }
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);
