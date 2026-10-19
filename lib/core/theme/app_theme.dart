import 'package:flutter/material.dart';

/// Material 3 theme for the whole app. One seed colour drives light and dark.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF00695C);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F8F7)
          : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? scheme.surface
            : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Status colours shared by chips, banners and timelines.
class StatusPalette {
  const StatusPalette._();

  static Color forAsset(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'available' => const Color(0xFF2E7D32),
      'reserved' => const Color(0xFFF9A825),
      'borrowed' => const Color(0xFF1565C0),
      'maintenance' => const Color(0xFFE65100),
      'retired' => scheme.outline,
      _ => scheme.outline,
    };
  }

  static Color forRequest(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'pending' => const Color(0xFFF9A825),
      'approved' => const Color(0xFF00897B),
      'released' => const Color(0xFF1565C0),
      'returned' => const Color(0xFF2E7D32),
      'declined' => scheme.error,
      'cancelled' => scheme.outline,
      _ => scheme.outline,
    };
  }

  static IconData iconForAsset(String status) => switch (status) {
        'available' => Icons.check_circle_rounded,
        'reserved' => Icons.event_available_rounded,
        'borrowed' => Icons.outbound_rounded,
        'maintenance' => Icons.build_rounded,
        'retired' => Icons.archive_rounded,
        _ => Icons.help_rounded,
      };

  static IconData iconForRequest(String status) => switch (status) {
        'pending' => Icons.hourglass_top_rounded,
        'approved' => Icons.thumb_up_rounded,
        'released' => Icons.outbound_rounded,
        'returned' => Icons.assignment_turned_in_rounded,
        'declined' => Icons.cancel_rounded,
        'cancelled' => Icons.remove_circle_outline_rounded,
        _ => Icons.help_rounded,
      };
}