import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../astro/angles.dart';
import '../../astro/models.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/object_thumb.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/catalog_repository.dart';
import '../../data/clock.dart';
import '../../data/location_service.dart';
import '../../data/settings.dart';
import '../../data/sky_providers.dart';
import '../../astro/sky_track.dart';
import 'altitude_chart.dart';
import 'find_it_guide.dart';
import 'solar_system_view.dart';

/// Screen 5: object detail. Positions recalculate on the 10 s clock tick.
class ObjectDetailScreen extends ConsumerWidget {
  const ObjectDetailScreen({super.key, required this.objectId});

  final String objectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final object = ref.watch(skyObjectProvider(objectId));
    final isFav = ref.watch(settingsProvider.select((s) => s.favourites.contains(objectId)));

    Widget body;
    if (catalog.isLoading) {
      body = const Padding(padding: EdgeInsets.all(20), child: ShimmerList(count: 3, height: 110));
    } else if (object == null) {
      body = const CosmoMessage(title: 'Object not found', message: 'It may have been removed from the catalog.');
    } else {
      body = _Body(object: object);
    }

    return Scaffold(
      body: Stack(children: [
        HeroBackground(
          asset: object?.image ?? 'assets/backgrounds/bg-detail.jpg',
          height: 330,
          alignment: const Alignment(0.2, -0.3),
        ),
        const LightBeams(top: 110),
        SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  IconSquareButton(icon: AppIcons.chevronLeft, semanticLabel: 'Back', onPressed: () => context.pop()),
                  const Spacer(),
                  IconSquareButton(
                    icon: AppIcons.heart,
                    semanticLabel: isFav ? 'Remove from saved' : 'Save object',
                    active: isFav,
                    color: isFav ? AppColors.pink : AppColors.text,
                    onPressed: object == null ? null : () => ref.read(settingsProvider.notifier).toggleFavourite(objectId),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: body),
          ]),
        ),
      ]),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.object});

  final SkyObject object;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocation = ref.watch(locationProvider.select((s) => s.hasLocation));
    final live = ref.watch(liveSkyProvider(object.id));
    final tonight = ref.watch(objectTonightProvider(object.id));
    final now = ref.watch(nowProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 96, 20, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          [object.catalog, object.subtype ?? object.type.name, if (object.constellation != null) object.constellation!]
              .join(' · ')
              .toUpperCase(),
          style: AppText.body(12, weight: FontWeight.w600, color: object.type.color).copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: 6),
        Text(object.name, style: AppText.screenTitle),
        if (object.summary != null) ...[
          const SizedBox(height: 8),
          Text(object.summary!, style: AppText.body(14, color: AppColors.textSoft, height: 1.45)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          if (object.raDeg != null) _Fact('RA', formatRa(object.raDeg!)),
          if (object.decDeg != null) _Fact('Dec', formatDec(object.decDeg!)),
          _Fact('Mag', formatMag(object.mag)),
          if (object.distance != null) _Fact('Dist', object.distance!),
        ]),
        const SizedBox(height: 18),
        if (!hasLocation)
          CosmoMessage(
            title: 'Location needed',
            message: 'Turn on location to see where this is in your sky.',
            actionLabel: 'Enable location',
            onAction: () => context.push(Routes.permission),
          )
        else ...[
          Row(children: [
            Expanded(
              child: _ReadoutTile(
                label: 'Altitude now',
                value: formatDeg(live?.horizontal.altDeg),
                note: live == null ? '' : (live.horizontal.isUp ? 'above horizon' : 'below horizon'),
                highlight: live?.horizontal.isUp ?? false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReadoutTile(
                label: 'Azimuth now',
                value: formatDeg(live?.horizontal.azDeg),
                note: live?.horizontal.compass ?? '',
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (tonight == null) const ShimmerBox(height: 240) else _TonightCard(tonight: tonight, now: now),
          const SizedBox(height: 14),
          if (tonight != null) _RiseSetRow(tonight: tonight),
          const SizedBox(height: 14),
          FindItGuide(objectId: object.id),
          if (planetFromId(object.id) case final planet? when SolarSystemView.supports(planet)) ...[
            const SizedBox(height: 14),
            SolarSystemView(planet: planet, name: object.name, now: now),
          ],
          const SizedBox(height: 18),
          GradientButton(
            label: 'Point me to it',
            icon: AppIcons.navigation,
            onPressed: () => context.push(Routes.point(object.id)),
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Show the math',
            icon: AppIcons.sigma,
            onPressed: () => context.push(Routes.math(object.id)),
          ),
        ],
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: AppText.body(12, color: AppColors.textMuted)),
        TextSpan(text: value, style: AppText.mono(12, color: AppColors.textSoft)),
      ]));
}

class _ReadoutTile extends StatelessWidget {
  const _ReadoutTile({required this.label, required this.value, required this.note, this.highlight = false});

  final String label;
  final String value;
  final String note;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final style = AppText.mono(30, weight: FontWeight.w500);
    return GlassCard(
      accent: highlight,
      radius: 20,
      semanticLabel: '$label $value $note',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.body(13, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          highlight ? GradientText(value, style: style) : Text(value, style: style),
          Text(note, style: AppText.body(12, color: AppColors.textSoft)),
        ]),
      ),
    );
  }
}

class _TonightCard extends StatelessWidget {
  const _TonightCard({required this.tonight, required this.now});

  final ObjectTonight tonight;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final night = tonight.night;
    final window = tonight.window;
    final kind = tonight.rts.kind;
    return GlassCard(
      radius: 22,
      strongBorder: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Altitude tonight', style: AppText.section)),
          if (kind == RiseSetKind.circumpolar)
            const StatusPill(label: 'Never sets from here', color: AppColors.cyan, icon: AppIcons.rotateCw),
        ]),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Dark ', style: AppText.body(13, color: AppColors.textSubtle)),
          TextSpan(
            text: night.hasDarkness ? formatRange(night.darkStart, night.darkEnd) : 'no full darkness',
            style: AppText.mono(13),
          ),
          if (window != null) ...[
            TextSpan(text: '  ·  Best ', style: AppText.body(13, color: AppColors.textSubtle)),
            TextSpan(text: formatRange(window.start, window.end), style: AppText.mono(13, color: AppColors.cyan)),
          ],
        ])),
        const SizedBox(height: 12),
        if (kind == RiseSetKind.neverRises || !tonight.visibleTonight)
          const CosmoMessage(
            pose: CosmoPose.telescope,
            cosmoSize: 80,
            title: 'Not visible from your location tonight',
            message: 'It stays below the horizon while the sky is dark.',
          )
        else
          AltitudeChart(
            samples: tonight.curve,
            now: now,
            darkStart: night.darkStart,
            darkEnd: night.darkEnd,
            peak: window?.peak ?? tonight.rts.transit,
          ),
      ]),
    );
  }
}

class _RiseSetRow extends StatelessWidget {
  const _RiseSetRow({required this.tonight});

  final ObjectTonight tonight;

  @override
  Widget build(BuildContext context) {
    final rts = tonight.rts;
    final peak = tonight.window?.peak ?? rts.transit;
    final peakAlt = tonight.window?.peakAltDeg ?? rts.transitAltDeg;
    final normal = rts.kind == RiseSetKind.normal;
    return Row(children: [
      Expanded(
        child: _EventTile(
          icon: AppIcons.sunrise,
          label: 'Rises',
          time: normal ? formatClock(rts.rise) : '—',
          detail: normal ? compass16(rts.riseAzDeg!) : (rts.kind == RiseSetKind.circumpolar ? 'always up' : 'never'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _EventTile(
          icon: AppIcons.star,
          label: 'Best',
          time: formatClock(peak),
          detail: '${peakAlt.round()}° ${compass16(rts.transitAzDeg)}',
          accent: true,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _EventTile(
          icon: AppIcons.sunset,
          label: 'Sets',
          time: normal ? formatClock(rts.set) : '—',
          detail: normal ? compass16(rts.setAzDeg!) : (rts.kind == RiseSetKind.circumpolar ? 'never' : '—'),
        ),
      ),
    ]);
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.icon, required this.label, required this.time, required this.detail, this.accent = false});

  final IconData icon;
  final String label;
  final String time;
  final String detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: accent,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      semanticLabel: '$label $time, $detail',
      child: ExcludeSemantics(
        child: Column(children: [
          Icon(icon, size: 20, color: accent ? AppColors.cyan : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(label, style: AppText.body(12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(time, style: AppText.mono(18, weight: FontWeight.w500)),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.mono(11, color: AppColors.textSoft)),
        ]),
      ),
    );
  }
}
