import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Dark theme colors
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceVariant = Color(0xFF262626);
  static const accent = Color(0xFFF6C945);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9E9E9E);

  // Light theme colors
  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF5F5F5);
  static const lightTextPrimary = Colors.black;
  static const lightTextSecondary = Color(0xFF666666);
}

ThemeData buildAppTheme({bool isDark = true}) {
  final bg = isDark ? AppColors.background : AppColors.lightBackground;
  final surface = isDark ? AppColors.surface : AppColors.lightSurface;
  final surfaceVariant = isDark ? AppColors.surfaceVariant : AppColors.lightSurfaceVariant;
  final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  final textSecondary = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

  final base = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.accent,
      surface: surface,
    ),
    scaffoldBackgroundColor: bg,
    textTheme: GoogleFonts.interTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.accent : textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.accent : textSecondary,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      textColor: textPrimary,
      iconColor: textSecondary,
    ),
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: textPrimary,
      unselectedLabelColor: textSecondary,
      indicatorColor: textPrimary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.black),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceVariant,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
      side: BorderSide.none,
    ),
  );
}
