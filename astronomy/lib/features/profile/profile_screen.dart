import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../astro/models.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/cosmo.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/object_thumb.dart';
import '../../core/widgets/sky_nav_bar.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/auth_service.dart';
import '../../data/catalog_repository.dart';
import '../../data/location_service.dart';
import '../../data/profile_repository.dart';
import '../../data/session.dart';
import '../../data/settings.dart';
import '../permission/manual_location_sheet.dart';
import 'auth_sheet.dart';

/// Screen 11: profile and settings.
///
/// Signed out, everything works on the device only. Signed in (email or
/// Google via Firebase Auth), the name, avatar, saved objects, settings and
/// home spot live in Firestore at `users/{uid}` and sync across devices.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = ref.watch(sessionProfileProvider);

    return Scaffold(
      body: Stack(children: [
        const HeroBackground(asset: 'assets/backgrounds/bg-profile.jpg', height: 300),
        const LightBeams(top: 100),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, SkyNavBar.reservedHeight),
            children: [
              Text('Profile', style: AppText.screenTitle),
              const SizedBox(height: 18),
              _Header(session: session, profile: profile),
              const SizedBox(height: 18),
              if (session == null) const _SignInCard() else _HomeSpotCard(home: profile?.home),
              const SizedBox(height: 22),
              Text('Saved objects', style: AppText.section),
              const SizedBox(height: 10),
              const _SavedObjects(),
              const SizedBox(height: 22),
              Text('Settings', style: AppText.section),
              const SizedBox(height: 10),
              const _SettingsCard(),
              const SizedBox(height: 22),
              const _AboutCard(),
              if (session != null) ...[
                const SizedBox(height: 18),
                GhostButton(
                  label: session.isTest ? 'Exit test login' : 'Sign out',
                  icon: AppIcons.logOut,
                  onPressed: () => ref.read(profileActionsProvider).signOut(),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: avatar, name, email
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.session, required this.profile});

  final Session? session;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = session;
    final pose = CosmoPose.values.asNameMap()[profile?.avatar] ?? CosmoPose.wave;
    final name = profile?.displayName ?? u?.displayName ?? u?.email?.split('@').first ?? 'Explorer';

    return Row(children: [
      Semantics(
        button: u != null,
        label: u == null ? 'Avatar' : 'Change avatar',
        child: GestureDetector(
          onTap: u == null ? null : () => _pickAvatar(context, ref, pose),
          child: _AvatarRing(pose: pose),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, style: AppText.display(26), overflow: TextOverflow.ellipsis)),
            if (u != null)
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(AppIcons.pencil, size: 18, color: AppColors.textSoft),
                onPressed: () => _editName(context, ref, name),
              ),
          ]),
          const SizedBox(height: 2),
          Text(
            u == null ? 'Not signed in · saved on this device only' : (u.email ?? 'Signed in'),
            style: AppText.body(13, color: AppColors.textSoft),
            overflow: TextOverflow.ellipsis,
          ),
          if (u != null) ...[
            const SizedBox(height: 8),
            u.isTest
                ? const StatusPill(label: 'Test login · this device only', color: AppColors.warm, icon: AppIcons.flaskConical)
                : StatusPill(label: 'Synced · ${u.providerLabel}', color: AppColors.cyan, icon: AppIcons.cloud),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        title: Text('Your name', style: AppText.section),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: AppText.body(15),
          cursorColor: AppColors.cyan,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == current) return;
    await ref.read(profileActionsProvider).setDisplayName(trimmed);
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref, CosmoPose current) async {
    const poses = [CosmoPose.wave, CosmoPose.telescope, CosmoPose.board, CosmoPose.phone];
    final picked = await showModalBottomSheet<CosmoPose>(
      context: context,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pick your Cosmo', style: AppText.section),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (final p in poses)
                Semantics(
                  button: true,
                  selected: p == current,
                  label: 'Cosmo ${p.name}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(ctx, p),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p == current ? AppColors.cyan : AppColors.surfaceBorder),
                      ),
                      child: Cosmo(pose: p, size: 56),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (picked != null && picked != current) await ref.read(profileActionsProvider).setAvatar(picked.name);
  }
}

/// Cosmo inside a slowly rotating cyan→violet ring.
class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.pose});

  final CosmoPose pose;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TimeBuilder(
          builder: (_, s, _) => Transform.rotate(
            angle: 2 * math.pi * loop01(s, 8),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [AppColors.cyan, AppColors.blue, AppColors.violet, AppColors.cyan]),
              ),
            ),
          ),
        ),
        Container(
          width: size - 6,
          height: size - 6,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
        ),
        Cosmo(pose: pose, size: 58),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Signed out: sign-in options
// ---------------------------------------------------------------------------

class _SignInCard extends ConsumerStatefulWidget {
  const _SignInCard();

  @override
  ConsumerState<_SignInCard> createState() => _SignInCardState();
}

class _SignInCardState extends ConsumerState<_SignInCard> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: true,
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Sign in to sync', style: AppText.cardTitle),
        const SizedBox(height: 4),
        Text(
          'Keep your saved objects, settings and home spot on every device.',
          style: AppText.body(13, color: AppColors.textSoft, height: 1.4),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: _busy ? 'Opening Google…' : 'Continue with Google',
          icon: AppIcons.logIn,
          onPressed: _busy ? null : _google,
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Sign in with email',
          icon: AppIcons.mail,
          onPressed: _busy ? null : () => showEmailAuthSheet(context),
        ),
        if (testLoginAvailable) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _busy ? null : () => ref.read(testLoginProvider.notifier).signIn(),
            icon: const Icon(AppIcons.flaskConical, size: 18, color: AppColors.warm),
            label: Text('Test login (debug builds only)',
                style: AppText.body(14, weight: FontWeight.w600, color: AppColors.warm)),
          ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Signed in: home observing spot
// ---------------------------------------------------------------------------

class _HomeSpotCard extends ConsumerWidget {
  const _HomeSpotCard({required this.home});

  final HomeSpot? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(locationProvider.select((s) => s.location));
    final h = home;
    final atHome = h != null && current != null && formatCoords(h.lat, h.lon) == current.observer.coordsLabel;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(AppIcons.house, size: 20, color: AppColors.cyan),
          const SizedBox(width: 8),
          Text('Home spot', style: AppText.cardTitle),
          const Spacer(),
          if (atHome) const StatusPill(label: 'in use', color: AppColors.cyan),
        ]),
        const SizedBox(height: 6),
        Text(
          h == null ? 'Not set. Save where you usually observe from.' : (h.label ?? formatCoords(h.lat, h.lon)),
          style: AppText.body(14, color: AppColors.textSoft),
        ),
        if (h != null) Text(formatCoords(h.lat, h.lon), style: AppText.mono(12, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: current == null
                  ? null
                  : () => ref.read(profileActionsProvider).setHome(
                        HomeSpot(lat: current.observer.latDeg, lon: current.observer.lonDeg, label: current.label),
                      ),
              child: Text(h == null ? 'Save current location' : 'Replace with current', textAlign: TextAlign.center),
            ),
          ),
          if (h != null && !atHome) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref
                    .read(locationProvider.notifier)
                    .setManual(Observer(latDeg: h.lat, lonDeg: h.lon), label: h.label ?? 'Home'),
                child: const Text('Observe from home', textAlign: TextAlign.center),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

extension on Observer {
  String get coordsLabel => formatCoords(latDeg, lonDeg);
}

// ---------------------------------------------------------------------------
// Saved objects
// ---------------------------------------------------------------------------

class _SavedObjects extends ConsumerWidget {
  const _SavedObjects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(settingsProvider.select((s) => s.favourites));
    if (ids.isEmpty) {
      return GlassCard(
        child: Row(children: [
          const Icon(AppIcons.heart, size: 20, color: AppColors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Tap the heart on any object to save it here.',
                style: AppText.body(14, color: AppColors.textSoft)),
          ),
        ]),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final id in ids.toList()..sort())
        Consumer(builder: (context, ref, _) {
          final o = ref.watch(skyObjectProvider(id));
          return ActionChip(
            avatar: Icon(AppIcons.sparkles, size: 16, color: o?.type.color ?? AppColors.pink),
            label: Text(o?.name ?? id, style: AppText.body(13, weight: FontWeight.w600)),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.surfaceBorderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onPressed: () => context.push(Routes.object(id)),
          );
        }),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Settings and about
// ---------------------------------------------------------------------------

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final loc = ref.watch(locationProvider.select((l) => l.location));
    final manual = loc?.source == LocationSource.manual;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        ListTile(
          leading: const Icon(AppIcons.mapPin, color: AppColors.cyan),
          title: Text('Location', style: AppText.body(15, weight: FontWeight.w600)),
          subtitle: Text(
            loc == null ? 'Not set' : (manual ? 'Manual · ${loc.displayLabel}' : 'Live GPS · ${loc.displayLabel}'),
            style: AppText.body(13, color: AppColors.textSoft),
          ),
          trailing: TextButton(
            onPressed: () => manual
                ? ref.read(locationProvider.notifier).requestPermission()
                : showManualLocationSheet(context),
            child: Text(manual ? 'Use GPS' : 'Change'),
          ),
        ),
        _Toggle(
          icon: AppIcons.eye,
          title: 'Red night-vision mode',
          subtitle: 'Keeps your eyes dark-adapted',
          value: s.nightVision,
          onChanged: c.setNightVision,
        ),
        _Toggle(
          icon: AppIcons.bell,
          title: 'Pass and peak alerts',
          subtitle: 'Reminders before events',
          value: s.alertsEnabled,
          onChanged: c.setAlerts,
        ),
        _Toggle(
          icon: AppIcons.compass,
          title: 'Precession correction',
          subtitle: 'Shift J2000 positions to today',
          value: s.precession,
          onChanged: c.setPrecession,
        ),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.cyan),
      title: Text(title, style: AppText.body(15, weight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppText.body(13, color: AppColors.textSoft)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.bg,
      activeTrackColor: AppColors.cyan,
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data sources', style: AppText.body(13, weight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          'Positions computed on your device · Satellites: N2YO and CelesTrak · Maps: OpenStreetMap',
          style: AppText.body(13, color: AppColors.textSoft, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text('About', style: AppText.body(13, weight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text('SkyGuide · a university Flutter lab project', style: AppText.body(13, color: AppColors.textSoft)),
      ]),
    );
  }
}
