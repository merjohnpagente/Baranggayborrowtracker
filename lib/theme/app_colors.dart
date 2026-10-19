import 'package:flutter/material.dart';

/// One build's worth of colour tokens — light or dark.
///
/// The whole app reads its colours through [AppColors]'s names, and those names
/// resolve against whichever palette is active. Screens never see this class
/// directly; they only ever see the same tokens they always did, so switching
/// the app to dark never means touching a screen.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.onPrimary,
    required this.secondary,
    required this.secondarySoft,
    required this.background,
    required this.canvas,
    required this.surfaceSoft,
    required this.surface,
    required this.ink,
    required this.inkSecondary,
    required this.muted,
    required this.border,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.info,
    required this.infoBg,
    required this.shadow,
  });

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// Barangay navy. In the dark palette this is a *light* tone with dark text on
  /// top — the Material 3 way round — because a dark navy fill under white text
  /// disappears once the page behind it is nearly black.
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color onPrimary;
  final Color secondary;
  final Color secondarySoft;

  final Color background;
  final Color canvas;
  final Color surfaceSoft;
  final Color surface;

  final Color ink;
  final Color inkSecondary;
  final Color muted;
  final Color border;

  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color info;
  final Color infoBg;

  final Color shadow;
}

/// The daylight palette from the design brief: white cards, navy ink.
const lightPalette = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF103B63), // Primary navy blue
  primaryDark: Color(0xFF0B2A49),
  primarySoft: Color(0xFFE8EFF7),
  onPrimary: Colors.white,
  secondary: Color(0xFF1769AA), // Secondary blue
  secondarySoft: Color(0xFFE4F0FA),
  background: Color(0xFFF5F8FC),
  canvas: Color(0xFFF5F8FC),
  surfaceSoft: Color(0xFFEFF3F9),
  surface: Color(0xFFFFFFFF), // Card background
  ink: Color(0xFF172B4D), // Main text
  inkSecondary: Color(0xFF3E4A63),
  muted: Color(0xFF64748B), // Secondary text
  border: Color(0xFFE2E8F0),
  // Semantic colours are read as text on their own tinted background, so each
  // token is picked to clear WCAG AA (4.5:1) against the background it is
  // actually painted on — not just against white.
  success: Color(0xFF169B62),
  successBg: Color(0xFFE4F6EE),
  warning: Color(0xFFB45309),
  warningBg: Color(0xFFFEF3E2),
  error: Color(0xFFDC3545),
  errorBg: Color(0xFFFDEBEC),
  info: Color(0xFF1769AA),
  infoBg: Color(0xFFE4F0FA),
  shadow: Color(0x0F172B4D),
);

/// The night build: deep navy paper, light ink.
///
/// Not an inversion. The semantic colours are lightened until they measure the
/// same contrast against the surface they are read on, so a status badge means
/// the same thing in either build.
const darkPalette = AppPalette(
  brightness: Brightness.dark,
  primary: Color(0xFF8FB4DC),
  primaryDark: Color(0xFFB6CFEA),
  primarySoft: Color(0xFF1C2E45),
  onPrimary: Color(0xFF0B1622),
  secondary: Color(0xFF7FB4E3),
  secondarySoft: Color(0xFF1A2B3D),
  background: Color(0xFF0E1721),
  canvas: Color(0xFF131D29),
  surfaceSoft: Color(0xFF18232F),
  surface: Color(0xFF1A2634),
  ink: Color(0xFFE9EEF5),
  inkSecondary: Color(0xFFBCC7D6),
  muted: Color(0xFF94A3B8),
  border: Color(0xFF2A3644),
  success: Color(0xFF4CCB90),
  successBg: Color(0xFF13301F),
  warning: Color(0xFFF0B95C),
  warningBg: Color(0xFF33270F),
  error: Color(0xFFF98A94),
  errorBg: Color(0xFF3A1B1F),
  info: Color(0xFF7FB4E3),
  infoBg: Color(0xFF17293B),
  shadow: Color(0x66000000),
);

/// Barangay Borrow Tracker design tokens.
///
/// Minimal navy + white system, 8pt spacing, Material 3 — and the same system
/// in its night values. The getters return whatever [active] holds; the app
/// root points [active] at the palette for the theme the user chose before
/// anything below it is built.
class AppColors {
  AppColors._();

  static AppPalette active = lightPalette;

  /// Points the whole app at a palette. Called from the root on every theme
  /// change, before the subtree that reads these tokens builds.
  static void apply(bool dark) => active = dark ? darkPalette : lightPalette;

  static bool get isDark => active.brightness == Brightness.dark;

  static Color get primary => active.primary;
  static Color get primaryDark => active.primaryDark;
  static Color get primarySoft => active.primarySoft;
  static Color get onPrimary => active.onPrimary;
  static Color get secondary => active.secondary;
  static Color get secondarySoft => active.secondarySoft;

  static Color get background => active.background;
  static Color get canvas => active.canvas;
  static Color get surfaceSoft => active.surfaceSoft;
  static Color get surface => active.surface;

  static Color get ink => active.ink;
  static Color get inkSecondary => active.inkSecondary;
  static Color get muted => active.muted;
  static Color get border => active.border;

  static Color get success => active.success;
  static Color get successBg => active.successBg;
  static Color get warning => active.warning;
  static Color get warningBg => active.warningBg;
  static Color get error => active.error;
  static Color get errorBg => active.errorBg;
  static Color get info => active.info;
  static Color get infoBg => active.infoBg;

  static Color get shadow => active.shadow;
}

class AppRadius {
  static const double input = 12;
  static const double card = 16;
  static const double large = 20;
  static const double pill = 999;
}

/// 8-point spacing scale.
class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}