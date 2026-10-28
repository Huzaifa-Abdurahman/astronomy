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
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/object_thumb.dart';
import '../../core/widgets/sky_nav_bar.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/location_service.dart';
import '../../data/sky_providers.dart';
import 'explore_controller.dart';

/// Screen 4: Explore — search and filter the catalog with live positions.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.initialFilter, this.focusSearch = false});

  /// A [SkyObjectType] name from the route (`/explore?type=galaxy`).
  final String? initialFilter;
  final bool focusSearch;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(exploreControllerProvider).query;
    _applyRoute();
  }

  @override
  void didUpdateWidget(ExploreScreen old) {
    super.didUpdateWidget(old);
    if (old.initialFilter != widget.initialFilter || old.focusSearch != widget.focusSearch) _applyRoute();
  }

  /// The tab stays alive, so route parameters are applied on every visit.
  void _applyRoute() {
    final f = ExploreFilter.fromTypeName(widget.initialFilter);
    if (f != null) Future.microtask(() => ref.read(exploreControllerProvider.notifier).showType(f));
    if (widget.focusSearch) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = ref.watch(locationProvider.select((s) => s.hasLocation));
    final results = ref.watch(exploreResultsProvider);
    final state = ref.watch(exploreControllerProvider);

    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-explore.jpg', height: 250),
        const LightBeams(top: 90),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList.list(children: [
                  Text('Explore', style: AppText.screenTitle),
                  const SizedBox(height: 4),
                  Text('Live positions for ${results?.length ?? '…'} objects', style: AppText.body(14, color: AppColors.textSoft)),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _search,
                    focusNode: _focus,
                    onChanged: ref.read(exploreControllerProvider.notifier).setQuery,
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    for (final f in ExploreFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          filter: f,
                          selected: state.isOn(f),
                          onTap: () => ref.read(exploreControllerProvider.notifier).toggle(f),
                        ),
                      ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              if (!hasLocation)
                SliverToBoxAdapter(
                  child: CosmoMessage(
                    title: 'Location needed',
                    message: 'Positions depend on where you are.',
                    actionLabel: 'Enable location',
                    onAction: () => context.push(Routes.permission),
                  ),
                )
              else if (results == null)
                const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: ShimmerList(count: 6)))
              else if (results.isEmpty)
                SliverToBoxAdapter(
                  child: CosmoMessage(
                    pose: CosmoPose.telescope,
                    title: 'Nothing matches',
                    message: state.visibleNow ? 'Nothing in this group is above the horizon right now.' : 'Try a name, M number or NGC number.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, SkyNavBar.reservedHeight),
                  sliver: SliverList.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ObjectRow(item: results[i]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(children: [
        const Icon(AppIcons.search, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: AppText.body(15),
            decoration: const InputDecoration(hintText: 'Name, Messier or NGC number', isCollapsed: true),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(AppIcons.x, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.filter, required this.selected, required this.onTap});

  final ExploreFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${filter.label} filter',
      excludeSemantics: true,
      child: Material(
        color: selected ? null : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accentBorder : AppColors.surfaceBorder)),
        child: Ink(
          decoration: selected ? const ShapeDecoration(shape: StadiumBorder(), gradient: AppColors.accentGradient) : null,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (filter == ExploreFilter.visibleNow) ...[
                  Icon(AppIcons.eye, size: 16, color: selected ? AppColors.cyan : AppColors.textMuted),
                  const SizedBox(width: 6),
                ],
                Text(filter.label,
                    style: AppText.body(13, weight: FontWeight.w600, color: selected ? AppColors.text : AppColors.textSoft)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.item});

  final SkyListItem item;

  @override
  Widget build(BuildContext context) {
    final o = item.object;
    final h = item.horizontal;
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(Routes.object(o.id)),
      semanticLabel: '${o.name}, ${o.subtype ?? o.type.name}. '
          '${h.isUp ? '${h.altDeg.round()} degrees up, ${h.compass}' : _belowLabel}',
      child: Row(children: [
        ObjectThumb(object: o),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              [if (!o.isSolarSystem) o.catalog, if (o.altId != null) o.altId!, o.subtype ?? o.type.name].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(12, color: o.type.color),
            ),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'RA ', style: AppText.body(12, color: AppColors.textMuted)),
                TextSpan(text: formatRa(item.equatorial.raDeg), style: AppText.mono(12, color: AppColors.textSoft)),
                TextSpan(text: '  mag ', style: AppText.body(12, color: AppColors.textMuted)),
                TextSpan(text: formatMag(o.mag), style: AppText.mono(12, color: AppColors.textSoft)),
              ]),
              maxLines: 1,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        if (h.isUp)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatDeg(h.altDeg), style: AppText.mono(17, weight: FontWeight.w500, color: AppColors.cyan)),
            Text(h.compass, style: AppText.mono(12, color: AppColors.textMuted)),
          ])
        else
          StatusPill(label: _belowShort, color: item.kind == RiseSetKind.neverRises ? AppColors.red : AppColors.warm),
      ]),
    );
  }

  String get _belowShort => item.kind == RiseSetKind.neverRises
      ? 'Never rises'
      : item.nextRise == null
          ? 'Rises later'
          : 'Rises ${formatClock(item.nextRise)}';

  String get _belowLabel => item.kind == RiseSetKind.neverRises ? 'never rises from here' : 'below the horizon, $_belowShort';
}
