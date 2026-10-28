import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography (CLAUDE.md §4.2).
///
/// * Display: Bricolage Grotesque 700–800, letter-spacing −0.03em.
/// * Body/UI: DM Sans 400–600.
/// * Numbers: DM Mono — every numeric astronomy readout uses [mono].
abstract final class AppText {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color color = AppColors.text}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.05,
        letterSpacing: -0.03 * size,
      );

  static TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.text, double? height}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.text}) =>
      GoogleFonts.dmMono(fontSize: size, fontWeight: weight, color: color);

  // Named shortcuts used across screens.
  static TextStyle get screenTitle => display(34);
  static TextStyle get heroTitle => display(38);
  static TextStyle get section => display(20, weight: FontWeight.w700);
  static TextStyle get cardTitle => display(18, weight: FontWeight.w700);
  static TextStyle get bodyM => body(15);
  static TextStyle get label => body(13, weight: FontWeight.w600);
  static TextStyle get caption => body(12, color: AppColors.textMuted);
}
