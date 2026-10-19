import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theme for Barangay Borrow Tracker.
/// Bundled Inter (assets/fonts), navy accents, a light and a dark build.
/// Fully offline — no runtime font downloads.
class AppTheme {
  static ThemeData light() => _build(lightPalette);

  static ThemeData dark() => _build(darkPalette);

  static ThemeData _build(AppPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      // Inter has to be set here, not only on the text theme. Every raw
      // `const TextStyle(...)` in the app inherits `fontFamily` from here, so
      // before this line text silently rendered in the platform default and the
      // UI read as "assembled" rather than designed.
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.secondary,
        surface: p.background,
        error: p.error,
      ),
      scaffoldBackgroundColor: p.background,
      // The screens read [AppColors] tokens; the theme only has to say which
      // palette is active and paint the Material surfaces not written by hand.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
    // Inter at a readable floor: secondary text sits at 13px with real
    // contrast, because these screens are read outdoors on a phone.
    final text = base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: p.ink,
      displayColor: p.ink,
    );
    return base.copyWith(
      textTheme: text.copyWith(
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: p.inkSecondary,
        ),
        labelSmall: text.labelSmall?.copyWith(
          fontSize: 12,
          color: p.inkSecondary,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontSize: 13,
          color: p.inkSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.ink,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        // A hairline plus a whisper of shadow: enough to lift a card off the
        // page without the "sticker" look of a heavy border.
        elevation: 1,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.primary : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.primary : p.muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        selectedIconTheme: IconThemeData(color: p.primary),
        unselectedIconTheme: IconThemeData(color: p.muted),
        selectedLabelTextStyle: TextStyle(
          color: p.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: p.muted),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: p.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // A surface-tinted field on a hairline, not grey on nothing: a bordered
        // box also gives the eye an edge to aim at when the keyboard is up.
        filled: true,
        fillColor: p.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: p.inkSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: p.muted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surfaceSoft,
        selectedColor: p.primarySoft,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceSoft : null,
        contentTextStyle: p.isDark ? TextStyle(color: p.ink) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: p.inkSecondary,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceSoft,
      ),
    );
  }
}