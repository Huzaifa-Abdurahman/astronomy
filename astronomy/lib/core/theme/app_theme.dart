import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // google_fonts 9's TextTheme helpers target the standalone material_ui
      // package, so set the family directly; TextStyle is shared by both.
      fontFamily: GoogleFonts.dmSans().fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.bg,
        primary: AppColors.cyan,
        onPrimary: AppColors.bg,
        secondary: AppColors.violet,
        onSecondary: AppColors.text,
        error: AppColors.red,
        onSurface: AppColors.text,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      splashFactory: InkSparkle.splashFactory,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.bg : AppColors.navInactive,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.cyan : AppColors.surfaceBase,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.surfaceBorderStrong),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceStrong,
        contentTextStyle: TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: InputBorder.none,
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.cyan),
    );
  }
}
