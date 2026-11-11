import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../astro/angles.dart';
import '../../astro/workings.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/cosmo.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/catalog_repository.dart';
import '../../data/clock.dart';
import '../../data/location_service.dart';
import '../../data/settings.dart';
import '../../data/sky_providers.dart';

/// Screen 7: the calculation behind "where is it now", step by step with
/// live numbers (CLAUDE.md §6). Everything is computed on the device, so this
/// screen works with no internet connection. Refreshes on the 10 s clock.
class MathScreen extends ConsumerWidget {
  const MathScreen({super.key, required this.objectId});

  final String objectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final object = ref.watch(skyObjectProvider(objectId));
    final catalogLoading = ref.watch(catalogProvider).isLoading;
    final observer = ref.watch(observerProvider);
    final fn = ref.watch(positionFnProvider(objectId));
    final now = ref.watch(nowProvider);
    final precess = ref.watch(settingsProvider.select((s) => s.precession));

    Widget body;
    if (catalogLoading) {
      body = const ShimmerList(count: 5, height: 110);
    } else if (object == null) {
      body = const CosmoMessage(title: 'Object not found', message: 'It may have been removed from the catalog.');
    } else if (observer == null || fn == null) {
      body = CosmoMessage(
        pose: CosmoPose.board,
        title: 'Location needed',
        message: 'The math needs your latitude and longitude.',
        actionLabel: 'Enable location',
        onAction: () => context.push(Routes.permission),
      );
    } else {
      final w = computeWorkings(fn(now), observer, now);
      body = _Steps(w: w, moving: object.isSolarSystem, precessed: precess && !object.isSolarSystem);
    }

    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-math.jpg', height: 280),
        const LightBeams(top: 110),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(children: [
                IconSquareButton(icon: AppIcons.chevronLeft, semanticLabel: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                const StatusPill(label: 'Offline · on device', color: AppColors.cyan, icon: AppIcons.cpu),
              ]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('The math', style: AppText.screenTitle),
                    const SizedBox(height: 4),
                    Text(
                      object == null ? 'Where is it in your sky?' : 'Where is ${object.name} right now?',
                      style: AppText.body(14, color: AppColors.textSoft),
                    ),
                  ]),
                ),
                const Cosmo(pose: CosmoPose.board, size: 84),
              ]),
              const SizedBox(height: 18),
              body,
            ],
          ),
        ),
      ]),
    );
  }
}

/// Number formatting for the workings: fixed decimals, true minus sign.
String _n(double v, [int digits = 3]) => v.toStringAsFixed(digits).replaceFirst('-', '−');
String _deg(double v, [int digits = 3]) => '${_n(v, digits)}°';

class _Steps extends StatelessWidget {
  const _Steps({required this.w, required this.moving, required this.precessed});

  final Workings w;

  /// Sun, Moon or a planet: RA/Dec were computed for this instant.
  final bool moving;

  /// Catalog coordinates precessed from J2000 to today.
  final bool precessed;

  @override
  Widget build(BuildContext context) {
    final utc = DateFormat('yyyy-MM-dd HH:mm:ss').format(w.time);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _InputsCard(w: w, utc: utc, note: moving ? 'α, δ computed for this instant' : (precessed ? 'α, δ precessed to today' : 'α, δ from the J2000 catalog')),
      const SizedBox(height: 14),
      _StepCard(
        n: 1,
        title: 'Julian Date',
        formula: 'JD = unixMillis / 86 400 000 + 2 440 587.5',
        working: '$utc UTC',
        result: 'JD = ${_n(w.jd, 5)}',
      ),
      _StepCard(
        n: 2,
        title: 'Days since J2000',
        formula: 'D = JD − 2 451 545.0',
        working: '${_n(w.jd, 5)} − 2 451 545.0',
        result: 'D = ${_n(w.d, 5)}',
      ),
      _StepCard(
        n: 3,
        title: 'Greenwich sidereal time',
        formula: 'GMST = 280.46061837 + 360.98564736629 · D',
        working: 'normalised to 0–360°',
        result: 'GMST = ${_deg(w.gmst)}',
      ),
      _StepCard(
        n: 4,
        title: 'Local sidereal time',
        formula: 'LST = GMST + λ',
        working: '${_deg(w.gmst)} + ${_deg(w.lonDeg, 4)}',
        result: 'LST = ${_deg(w.lst)}',
      ),
      _StepCard(
        n: 5,
        title: 'Hour angle',
        formula: 'H = LST − α   (−180…+180°)',
        working: '${_deg(w.lst)} − ${_deg(w.raDeg, 4)}',
        result: 'H = ${_deg(w.hourAngle)}',
        note: w.hourAngle < 0 ? 'Negative: still east of the meridian, climbing.' : 'Positive: past the meridian, sinking west.',
      ),
      _StepCard(
        n: 6,
        title: 'Altitude',
        formula: 'sin(alt) = sin δ · sin φ + cos δ · cos φ · cos H',
        working: 'sin(alt) = ${_n(w.sinAlt, 5)}',
        result: 'alt = ${_deg(w.altDeg, 2)}',
        highlight: true,
        note: w.refractionDeg > 0
            ? 'With refraction R = ${_n(w.refractionDeg * 60, 2)}′ the apparent altitude is ${_deg(w.apparentAltDeg, 2)}.'
            : 'Below the horizon, so no refraction is added.',
      ),
      _StepCard(
        n: 7,
        title: 'Azimuth',
        formula: 'cos A = (sin δ − sin alt · sin φ) / (cos alt · cos φ)',
        working: 'cos A = ${_n(w.cosA, 5)}  →  A = ${_deg(w.aRaw, 2)}'
            '${w.westOfMeridian ? '\nsin H > 0 (west), so A = 360° − A' : ''}',
        result: 'A = ${_deg(w.azDeg, 2)}  ${w.compass}',
        highlight: true,
        note: 'Measured from north, clockwise: N 0°, E 90°, S 180°, W 270°.',
      ),
      _RiseSetCard(w: w),
    ]);
  }
}

class _InputsCard extends StatelessWidget {
  const _InputsCard({required this.w, required this.utc, required this.note});

  final Workings w;
  final String utc;
  final String note;

  @override
  Widget build(BuildContext context) {
    Widget cell(String sym, String label, String value) => Expanded(
          child: Semantics(
            label: '$label $value',
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$sym  $label', style: AppText.body(12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: AppText.mono(16, weight: FontWeight.w500)),
            ]),
          ),
        );
    return GlassCard(
      strongBorder: true,
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Inputs', style: AppText.cardTitle),
        const SizedBox(height: 12),
        Row(children: [cell('φ', 'latitude', _deg(w.latDeg, 4)), cell('λ', 'longitude', _deg(w.lonDeg, 4))]),
        const SizedBox(height: 12),
        Row(children: [cell('α', 'right ascension', _deg(w.raDeg, 4)), cell('δ', 'declination', _deg(w.decDeg, 4))]),
        const SizedBox(height: 10),
        Text('α = ${formatRa(w.raDeg)} · δ = ${formatDec(w.decDeg)}', style: AppText.mono(12, color: AppColors.textSoft)),
        const SizedBox(height: 4),
        Text('$note · updates every 10 s', style: AppText.caption),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.n,
    required this.title,
    required this.formula,
    required this.working,
    required this.result,
    this.note,
    this.highlight = false,
  });

  final int n;
  final String title;
  final String formula;
  final String working;
  final String result;
  final String? note;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final resultStyle = AppText.mono(highlight ? 22 : 17, weight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        accent: highlight,
        radius: 20,
        padding: const EdgeInsets.all(16),
        semanticLabel: 'Step $n, $title. $result',
        child: ExcludeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: highlight ? AppColors.primaryGradient : null,
                border: highlight ? null : Border.all(color: AppColors.surfaceBorderStrong),
              ),
              child: Text('$n', style: AppText.mono(14, weight: FontWeight.w500, color: highlight ? AppColors.bg : AppColors.cyan)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.body(15, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(formula, style: AppText.mono(12, color: AppColors.violetSoft)),
                const SizedBox(height: 4),
                Text(working, style: AppText.mono(12, color: AppColors.textSoft)),
                const SizedBox(height: 6),
                highlight ? GradientText(result, style: resultStyle) : Text(result, style: resultStyle),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(note!, style: AppText.body(12, color: AppColors.textSoft, height: 1.35)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RiseSetCard extends StatelessWidget {
  const _RiseSetCard({required this.w});

  final Workings w;

  @override
  Widget build(BuildContext context) {
    final String verdict;
    if (w.circumpolar) {
      verdict = 'cos H0 < −1: circumpolar. Never sets from here.';
    } else if (w.neverRises) {
      verdict = 'cos H0 > 1: never rises at this latitude.';
    } else {
      final hours = w.h0Deg! / 15 / 1.0027379;
      verdict = 'H0 = ${_deg(w.h0Deg!, 2)} → above the horizon ${_n(2 * hours, 1)} h per day '
          '(rise = transit − H0, set = transit + H0).';
    }
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(AppIcons.sigma, size: 18, color: AppColors.cyan),
          const SizedBox(width: 8),
          Text('Bonus: rise, transit and set', style: AppText.body(15, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text('cos H0 = (sin h0 − sin φ · sin δ) / (cos φ · cos δ),  h0 = −0.5667°',
            style: AppText.mono(12, color: AppColors.violetSoft)),
        const SizedBox(height: 4),
        Text('cos H0 = ${_n(w.cosH0, 5)}', style: AppText.mono(12, color: AppColors.textSoft)),
        const SizedBox(height: 6),
        Text(verdict, style: AppText.body(13, height: 1.4)),
        const SizedBox(height: 6),
        Text(
          'Highest at transit: ${formatDeg(w.transitAltDeg)} due ${w.transitAzDeg == 180 ? 'south' : 'north'} '
          '(90° − |φ − δ|).',
          style: AppText.body(13, color: AppColors.textSoft),
        ),
      ]),
    );
  }
}
