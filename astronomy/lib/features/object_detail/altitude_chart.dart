import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../astro/models.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/motion.dart';

/// Altitude-tonight curve (CLAUDE.md §5 #5): noon → 08:00, the dark window
/// shaded, a "now" marker, and a draw-in from left to right over 2.4 s.
class AltitudeChart extends StatelessWidget {
  const AltitudeChart({super.key, required this.samples, required this.now, this.darkStart, this.darkEnd, this.peak});

  final List<AltitudeSample> samples;
  final DateTime now;
  final DateTime? darkStart;
  final DateTime? darkEnd;
  final DateTime? peak;

  double _x(DateTime t) => t.difference(samples.first.time).inSeconds / 3600;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) return const SizedBox(height: 180);
    final maxX = _x(samples.last.time);
    final reduce = reduceMotionOf(context);
    final spots = [for (final s in samples) FlSpot(_x(s.time), s.altDeg.clamp(-30, 90).toDouble())];

    return Semantics(
      label: _summary(),
      child: SizedBox(
        height: 190,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 2400),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            final visible = spots.where((s) => s.x <= maxX * progress).toList();
            return LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: -30,
                maxY: 90,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                rangeAnnotations: RangeAnnotations(
                  verticalRangeAnnotations: [
                    if (darkStart != null && darkEnd != null)
                      VerticalRangeAnnotation(
                        x1: _x(darkStart!).clamp(0, maxX),
                        x2: _x(darkEnd!).clamp(0, maxX),
                        color: AppColors.violet.withValues(alpha: 0.14),
                      ),
                  ],
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                  verticalLines: [
                    if (_x(now) >= 0 && _x(now) <= maxX)
                      VerticalLine(
                        x: _x(now),
                        color: AppColors.cyan,
                        strokeWidth: 1.5,
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: AppText.mono(11, color: AppColors.cyan),
                          labelResolver: (_) => 'now',
                        ),
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 30,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text('${v.round()}°', style: AppText.mono(10, color: AppColors.textMuted)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 4,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text(
                                formatClock(samples.first.time.add(Duration(minutes: (v * 60).round()))),
                                style: AppText.mono(10, color: AppColors.textMuted),
                              ),
                            ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceStrong,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${formatClock(samples.first.time.add(Duration(minutes: (s.x * 60).round())))}  ${s.y.toStringAsFixed(1)}°',
                          AppText.mono(12, color: AppColors.text),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: visible.isEmpty ? [spots.first] : visible,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    barWidth: 2.5,
                    gradient: AppColors.primaryGradient,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      cutOffY: 0,
                      applyCutOffY: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.cyan.withValues(alpha: 0.28), AppColors.cyan.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _summary() {
    final maxAlt = samples.map((s) => s.altDeg).reduce((a, b) => a > b ? a : b);
    return 'Altitude chart from ${formatClock(samples.first.time)} to ${formatClock(samples.last.time)}. '
        'Highest ${maxAlt.toStringAsFixed(0)} degrees${peak == null ? '' : ' at ${formatClock(peak)}'}.';
  }
}
