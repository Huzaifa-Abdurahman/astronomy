import 'package:flutter/material.dart';

/// SkyGuide design tokens (CLAUDE.md §4.1).
abstract final class AppColors {
  static const bg = Color(0xFF070A1F);
  static const surfaceBase = Color(0xFF0E1334);
  static const surface = Color(0xE00E1334); // ~88%
  static const surfaceStrong = Color(0xF00E1334); // ~94%, nav bar
  static const surfaceBorder = Color(0xFF26306A);
  static const surfaceBorderStrong = Color(0xFF2F3A7C);
  static const inputBorder = Color(0xFF3A4590);

  static const cyan = Color(0xFF3EE7FF);
  static const blue = Color(0xFF7C8CFF);
  static const violet = Color(0xFFA06BFF);
  static const violetSoft = Color(0xFFC3A6FF);
  static const pink = Color(0xFFFF8FE0);
  static const warm = Color(0xFFFFD27A);
  static const red = Color(0xFFFF8A7A);
  static const planetBlue = Color(0xFF7FA2FF);

  static const text = Color(0xFFF2F4FF);
  static const textSoft = Color(0xFFD8DCF2);
  static const textSubtle = Color(0xFFC3C9E8);
  static const textMuted = Color(0xFFA9B1D6);
  static const navInactive = Color(0xFF8E97C2);

  static const accentBorder = Color(0xFF4FC9EA);
  static const glassChip = Color(0x8C070A1F); // bg @55%
  static const glassChipBorder = Color(0x24FFFFFF);

  /// Primary cyan → blue → violet gradient, left to right.
  static const primaryGradient = LinearGradient(
    colors: [cyan, blue, violet],
    stops: [0, 0.55, 1],
  );

  /// Accent card fill: cyan@22% → violet@22% diagonal.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x383EE7FF), Color(0x38A06BFF)],
  );

  static List<BoxShadow> cyanGlow([double opacity = 0.32]) => [
        BoxShadow(
          color: cyan.withValues(alpha: opacity),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ];
}
