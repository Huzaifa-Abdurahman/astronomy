import 'package:flutter/material.dart';

import '../../astro/orbit.dart';
import '../../astro/sky_track.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/sky_dome.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/n2yo_api.dart';

/// A satellite pass drawn on the sky dome, with the satellite sliding along
/// the arc on a loop so you can see where it appears, peaks and vanishes.
///
/// While the pass is actually happening the dot follows the clock instead.
/// If the satellite is above the horizon right now (from N2YO's live
/// position), that is shown as well.
class PassArcView extends StatelessWidget {
  const PassArcView({super.key, required this.pass, required this.name, this.live, this.now, this.loopSeconds = 8});

  final SatPass pass;
  final String name;
  final SatSample? live;
  final DateTime? now;
  final double loopSeconds;

  @override
  Widget build(BuildContext context) {
    final arc = passArc(
      start: pass.start,
      startAltDeg: pass.startEl,
      startAzDeg: pass.startAz,
      max: pass.max,
      maxAltDeg: pass.maxEl,
      maxAzDeg: pass.maxAz,
      end: pass.end,
      endAltDeg: pass.endEl,
      endAzDeg: pass.endAz,
    );
    final n = now ?? DateTime.now().toUtc();
    final total = pass.end.difference(pass.start).inMilliseconds;
    final inProgress = total > 0 && !n.isBefore(pass.start) && !n.isAfter(pass.end);
    final liveUp = live != null && live!.isUp;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TimeBuilder(
        restSeconds: loopSeconds * 0.5,
        builder: (context, s, _) {
          final f = inProgress ? n.difference(pass.start).inMilliseconds / total : loop01(s, loopSeconds);
          final p = trackPointAtFraction(arc, f);
          return SkyDome(
            tracks: [DomeTrack(points: arc, color: AppColors.violetSoft)],
            markers: [
              DomeMarker(altDeg: arc.first.altDeg, azDeg: arc.first.azDeg, color: AppColors.warm, size: 4, label: 'appears ${formatClock(pass.start)}'),
              DomeMarker(altDeg: pass.maxEl, azDeg: pass.maxAz, color: AppColors.warm, size: 4, star: true, label: '${pass.maxEl.round()}°'),
              DomeMarker(altDeg: arc.last.altDeg, azDeg: arc.last.azDeg, color: AppColors.warm, size: 4, label: 'gone ${formatClock(pass.end)}'),
              DomeMarker(altDeg: p.altDeg, azDeg: p.azDeg, color: AppColors.cyan, pulse: inProgress, size: 7, label: inProgress ? 'now' : formatClock(p.time)),
              if (liveUp && !inProgress)
                DomeMarker(altDeg: live!.elDeg, azDeg: live!.azDeg, color: AppColors.pink, pulse: true, size: 6, label: 'live now'),
            ],
            seconds: s,
            semanticLabel: '$name pass: ${pass.pathText}',
          );
        },
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        StatusPill(label: 'Appears ${pass.startAzCompass}', color: AppColors.warm, icon: AppIcons.sunrise),
        StatusPill(label: 'Peak ${pass.maxEl.round()}° ${pass.maxAzCompass}', color: AppColors.cyan, icon: AppIcons.star),
        StatusPill(label: 'Gone ${pass.endAzCompass}', color: AppColors.warm, icon: AppIcons.sunset),
        if (pass.mag != null) StatusPill(label: 'mag ${pass.mag!.toStringAsFixed(1)}', color: AppColors.violetSoft),
      ]),
      const SizedBox(height: 8),
      Text(
        'A ${(pass.durationS / 60).round().clamp(1, 99)}-minute pass. $name looks like a steady bright star gliding '
        'across the sky, with no blinking lights. At its highest it is ${fistsText(pass.maxEl)}.',
        style: AppText.body(13, color: AppColors.textSoft, height: 1.4),
      ),
    ]);
  }
}
