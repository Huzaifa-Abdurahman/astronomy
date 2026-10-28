import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/hero_background.dart';
import '../../core/widgets/light_beams.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/sky_logo.dart';
import '../../core/widgets/twinkle_stars.dart';

/// Screen 1: first-launch welcome (CLAUDE.md §5).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _slides = [
    ('Explore beyond your ', 'horizon', 'Find stars, planets and galaxies from exactly where you stand.'),
    ('Know exactly ', 'when to look', 'Rise, peak and set times plus the darkest window, worked out on your phone.'),
    ('Point and ', 'find it', 'Your compass and tilt sensors guide you straight to the target.'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: HeroBackground(asset: 'assets/backgrounds/bg-onboard.jpg')),
        const TwinkleStars(count: 34),
        const LightBeams(top: 300),
        const _ShootingStar(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SkyLogo(),
              const Spacer(),
              const _FeatureRow(),
              const SizedBox(height: 26),
              SizedBox(
                height: 170,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final (lead, accent, body) = _slides[i];
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: lead),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GradientText(accent, style: AppText.heroTitle),
                          ),
                        ]),
                        style: AppText.heroTitle,
                      ),
                      const SizedBox(height: 12),
                      Text(body, style: AppText.body(15, color: AppColors.textSoft, height: 1.45)),
                    ]);
                  },
                ),
              ),
              _Dots(count: _slides.length, index: _page),
              const SizedBox(height: 22),
              GradientButton(
                label: 'Get started',
                icon: AppIcons.arrowRight,
                onPressed: () => context.go(Routes.permission),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  static const _items = [
    (AppIcons.mapPin, 'Live location', AppColors.cyan),
    (AppIcons.sparkles, 'Sky objects', AppColors.violetSoft),
    (AppIcons.clock, 'When to look', AppColors.warm),
    (AppIcons.satellite, 'Satellites', AppColors.pink),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final (icon, label, color) in _items)
        Expanded(
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: AppText.body(12, weight: FontWeight.w600, color: AppColors.textSoft)),
          ]),
        ),
    ]);
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: i == index ? AppColors.primaryGradient : null,
              color: i == index ? null : AppColors.navInactive.withValues(alpha: 0.5),
            ),
          ),
      ]),
    );
  }
}

/// A short line that streaks diagonally across the sky every ~7 s.
class _ShootingStar extends StatelessWidget {
  const _ShootingStar();

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: TimeBuilder(builder: (context, s, _) {
          final t = loop01(s, 7, 5.5);
          const flight = 0.12; // the streak lasts ~0.85 s of the 7 s cycle
          if (t > flight) return const SizedBox.shrink();
          final p = t / flight;
          final size = MediaQuery.sizeOf(context);
          final start = Offset(size.width * 0.85, size.height * 0.08);
          final end = Offset(size.width * 0.25, size.height * 0.32);
          final head = Offset.lerp(start, end, p)!;
          return CustomPaint(painter: _StreakPainter(head, end - start, lerpDouble(1, 0, p)!));
        }),
      ),
    );
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter(this.head, this.direction, this.opacity);

  final Offset head;
  final Offset direction;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final tail = head - direction / direction.distance * 90;
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [Colors.transparent, AppColors.text.withValues(alpha: opacity)])
            .createShader(Rect.fromPoints(tail, head)),
    );
    canvas.drawCircle(head, 2.2, Paint()..color = AppColors.cyan.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(_StreakPainter old) => old.head != head;
}
