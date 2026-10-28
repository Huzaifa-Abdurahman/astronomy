import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../core/widgets/sky_nav_bar.dart';
import '../../core/widgets/state_views.dart';
import '../../data/catalog_repository.dart';
import '../../data/clock.dart';
import '../../data/location_service.dart';
import '../../data/sky_providers.dart';
import '../permission/manual_location_sheet.dart';

/// Screen 3: Home (CLAUDE.md §5; layout from "03 · Home" in the design file).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-home.jpg', height: 342, flip: true),
        const LightBeams(top: 140),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, SkyNavBar.reservedHeight),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _TopBar(),
              const SizedBox(height: 22),
              const _Greeting(),
              const SizedBox(height: 16),
              const _SearchBar(),
              const SizedBox(height: 16),
              const _CategoryTiles(),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(child: Text("Tonight's highlight", style: AppText.section)),
                TextButton(
                  onPressed: () => context.go(Routes.explore),
                  child: Text('View all', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.cyan)),
                ),
              ]),
              const SizedBox(height: 8),
              const _HighlightCard(),
              const SizedBox(height: 16),
              const _QuickTiles(),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    final label = location.location?.displayLabel ?? (location.status == LocationStatus.locating ? 'Locating…' : 'Set location');
    return Row(children: [
      IconSquareButton(
        icon: AppIcons.menu,
        semanticLabel: 'Menu and settings',
        onPressed: () => context.go(Routes.profile),
      ),
      const Spacer(),
      Semantics(
        button: true,
        label: 'Location: $label. Change location',
        excludeSemantics: true,
        child: Material(
          color: AppColors.glassChip,
          shape: const StadiumBorder(side: BorderSide(color: AppColors.glassChipBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showManualLocationSheet(context),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              constraints: const BoxConstraints(maxWidth: 230),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  location.location?.source == LocationSource.manual ? AppIcons.mapPinned : AppIcons.mapPin,
                  size: 18,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.body(14, weight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                const Icon(AppIcons.chevronDown, size: 16, color: AppColors.textSubtle),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  static String greetingFor(DateTime local) {
    final h = local.hour;
    if (h >= 5 && h < 12) return 'Good morning,';
    if (h >= 12 && h < 17) return 'Good afternoon,';
    if (h >= 17 && h < 22) return 'Good evening,';
    return 'Clear skies,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).toLocal();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(greetingFor(now), style: AppText.body(17, color: AppColors.textSoft)),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Explorer '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GradientText('✦', style: AppText.heroTitle),
          ),
        ]),
        style: AppText.heroTitle,
      ),
      const SizedBox(height: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          'The sky is always there. We help you find it.',
          style: AppText.body(14, color: AppColors.textSubtle, height: 1.4),
        ),
      ),
    ]);
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search the sky',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('${Routes.explore}?search=1'),
          child: SizedBox(
            height: 52,
            child: Row(children: [
              const SizedBox(width: 16),
              const Icon(AppIcons.search, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search a star, galaxy or planet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(15, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles();

  static const _types = [SkyObjectType.star, SkyObjectType.planet, SkyObjectType.galaxy, SkyObjectType.nebula];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < _types.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: _CategoryTile(type: _types[i], accent: i == 0)),
      ],
    ]);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.type, required this.accent});

  final SkyObjectType type;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: GlassCard(
        accent: accent,
        radius: 18,
        padding: EdgeInsets.zero,
        semanticLabel: 'Browse ${type.plural}',
        onTap: () => context.go('${Routes.explore}?type=${type.name}'),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(type.icon, size: 24, color: accent ? AppColors.text : type.color),
            const SizedBox(height: 6),
            Text(type.plural,
                style: AppText.body(13, weight: FontWeight.w600, color: accent ? AppColors.text : AppColors.textSoft)),
          ]),
        ),
      ),
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    if (!location.hasLocation) {
      return GlassCard(
        strongBorder: true,
        radius: 24,
        child: CosmoMessage(
          title: 'Where are you?',
          message: 'SkyGuide needs your location to work out what is in your sky.',
          actionLabel: 'Enable location',
          onAction: () => context.push(Routes.permission),
          cosmoSize: 90,
        ),
      );
    }
    final catalog = ref.watch(catalogProvider);
    if (catalog.hasError) {
      return const GlassCard(child: CosmoMessage(title: 'Catalog failed to load', message: 'Please restart the app.'));
    }
    final id = ref.watch(highlightProvider);
    if (id == null) {
      final night = ref.watch(nightProvider);
      if (catalog.isLoading || night == null) return const ShimmerBox(height: 190, radius: 24);
      return GlassCard(
        radius: 24,
        child: CosmoMessage(
          pose: CosmoPose.telescope,
          title: night.hasDarkness ? 'Nothing bright is up yet' : 'No full darkness tonight',
          message: night.hasDarkness
              ? 'Browse the catalog to plan for later tonight.'
              : 'At this time of year the Sun never gets 18° below your horizon.',
          cosmoSize: 90,
        ),
      );
    }

    final object = ref.watch(skyObjectProvider(id))!;
    final live = ref.watch(liveSkyProvider(id));
    final tonight = ref.watch(objectTonightProvider(id));
    final peak = tonight?.window?.peak ?? tonight?.rts.transit;

    return GlassCard(
      radius: 24,
      strongBorder: true,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routes.object(id)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ObjectThumb(object: object, size: 96, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(object.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                  ),
                  const Icon(AppIcons.chevronRight, size: 18, color: AppColors.textMuted),
                ]),
                const SizedBox(height: 5),
                Text('${object.catalog} · ${object.subtype ?? object.type.name}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, color: AppColors.violetSoft)),
                const SizedBox(height: 5),
                _LabelledMono(parts: [
                  ('Peak ', formatClock(peak)),
                  (' · Dark ', formatRange(tonight?.night.darkStart, tonight?.night.darkEnd)),
                ]),
                const SizedBox(height: 5),
                _LabelledMono(
                  valueColor: AppColors.cyan,
                  parts: [
                    (
                      'Now ',
                      live == null
                          ? '—'
                          : '${live.horizontal.compass} ${live.horizontal.azDeg.round()}° · ${formatDeg(live.horizontal.altDeg)} up'
                    ),
                  ],
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GradientButton(
          label: 'Point me to it',
          icon: AppIcons.navigation,
          height: 50,
          radius: 16,
          onPressed: () => context.push(Routes.point(id)),
        ),
      ]),
    );
  }
}

/// "Label value" pairs where the values are DM Mono (numbers).
class _LabelledMono extends StatelessWidget {
  const _LabelledMono({required this.parts, this.valueColor = AppColors.text});

  final List<(String, String)> parts;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        for (final (label, value) in parts) ...[
          TextSpan(text: label, style: AppText.body(13, color: AppColors.textSubtle)),
          TextSpan(text: value, style: AppText.mono(13, color: valueColor)),
        ],
      ]),
      maxLines: 2,
    );
  }
}

class _QuickTiles extends ConsumerWidget {
  const _QuickTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final night = ref.watch(nightProvider);
    return Row(children: [
      Expanded(
        child: _QuickTile(
          icon: AppIcons.calendar,
          color: AppColors.violetSoft,
          title: "Tonight's plan",
          subtitle: night?.sunset == null ? 'Timeline' : 'Sunset ${formatClock(night!.sunset)}',
          onTap: () => context.push(Routes.tonight),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickTile(
          icon: AppIcons.mountain,
          color: AppColors.cyan,
          title: 'Dark-sky spots',
          subtitle: 'Near you',
          onTap: () => context.go(Routes.nearby),
        ),
      ),
    ]);
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      semanticLabel: '$title, $subtitle',
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}
