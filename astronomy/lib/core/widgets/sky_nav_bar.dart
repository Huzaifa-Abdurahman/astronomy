import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text.dart';

/// Floating 5-tab bottom navigation: Home · Explore · Map · Satellites · Profile.
/// The active tab is cyan with a small glowing dot.
class SkyNavBar extends StatelessWidget {
  const SkyNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Space screens should leave at the bottom so content clears the bar.
  static const double reservedHeight = 104;

  static const _items = [
    (AppIcons.house, 'Home'),
    (AppIcons.compass, 'Explore'),
    (AppIcons.map, 'Map'),
    (AppIcons.satellite, 'Satellites'),
    (AppIcons.user, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + bottomInset * 0.5),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: const [BoxShadow(color: Color(0xB3070A1F), blurRadius: 30, offset: Offset(0, -8))],
        ),
        child: Semantics(
          container: true,
          label: 'Main navigation',
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(child: _NavItem(icon: _items[i].$1, label: _items[i].$2, active: i == currentIndex, onTap: () => onTap(i))),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.cyan : AppColors.navInactive;
    return Semantics(
      button: true,
      selected: active,
      label: '$label tab',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppText.body(11, weight: active ? FontWeight.w600 : FontWeight.w500, color: color)),
          const SizedBox(height: 3),
          AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.cyan,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.cyan, blurRadius: 8)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
