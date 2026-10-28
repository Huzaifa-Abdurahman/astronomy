import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// True when the OS asks for reduced motion (CLAUDE.md §4.4).
bool reduceMotionOf(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Smooth 0 → 1 → 0 wave with the given [period] in seconds.
/// [offset] shifts the phase (seconds), used to stagger elements.
double pingPong(double seconds, double period, [double offset = 0]) =>
    0.5 - 0.5 * math.cos(2 * math.pi * (seconds + offset) / period);

/// Sawtooth 0 → 1 with the given [period] in seconds.
double loop01(double seconds, double period, [double offset = 0]) =>
    ((seconds + offset) % period) / period;

/// Rebuilds [builder] every frame with the elapsed time in seconds.
///
/// All looping effects in the app are written as pure functions of time, so a
/// single ticker per effect is enough. When reduced motion is on the ticker is
/// stopped and [builder] receives [restSeconds] once, giving a static frame.
class TimeBuilder extends StatefulWidget {
  const TimeBuilder({super.key, required this.builder, this.child, this.restSeconds = 0});

  final Widget Function(BuildContext context, double seconds, Widget? child) builder;
  final Widget? child;
  final double restSeconds;

  @override
  State<TimeBuilder> createState() => _TimeBuilderState();
}

class _TimeBuilderState extends State<TimeBuilder> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6);
  late final ValueNotifier<double> _seconds = ValueNotifier(widget.restSeconds);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      if (_ticker.isActive) _ticker.stop();
      _seconds.value = widget.restSeconds;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, s, child) => widget.builder(context, s, child),
        child: widget.child,
      );
}
