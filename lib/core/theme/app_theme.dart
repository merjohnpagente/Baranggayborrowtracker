import 'package:flutter/material.dart';

/// Material 3 theme for the whole app.
///
/// The palette is fixed by the barangay's identity, not derived from an
/// arbitrary seed: navy and the lighter blue are the two colours used on the
/// signage and the paper forms, so the app and the paperwork agree.
class AppTheme {
  const AppTheme._();

  /// Primary — headings, app bar, selected navigation.
  static const Color navy = Color(0xFF103B63);

  /// Secondary — links, accents, "released" states.
  static const Color blue = Color(0xFF1769AA);

  /// Page background. A very light blue-grey rather than pure white, so white
  /// cards separate from it without needing a heavy border.
  static const Color background = Color(0xFFF5F8FC);

  static const Color success = Color(0xFF169B62);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC3545);

  static const Color _ink = Color(0xFF14202B);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final seeded = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: brightness,
    );

    final scheme = brightness == Brightness.light
        ? seeded.copyWith(
            primary: navy,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFD7E6F5),
            onPrimaryContainer: navy,
            secondary: blue,
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFDCEBFA),
            onSecondaryContainer: const Color(0xFF0B2C4A),
            error: danger,
            onError: Colors.white,
            surface: Colors.white,
            onSurface: _ink,
            outlineVariant: const Color(0xFFD6E0EA),
          )
        : seeded.copyWith(
            primary: const Color(0xFF9CC7F0),
            onPrimary: const Color(0xFF04263F),
            primaryContainer: const Color(0xFF1A4566),
            onPrimaryContainer: const Color(0xFFD6E9FC),
            secondary: const Color(0xFF8FC4F5),
            onSecondary: const Color(0xFF05263E),
            secondaryContainer: const Color(0xFF143E5D),
            onSecondaryContainer: const Color(0xFFD7EAFB),
            error: const Color(0xFFFF8A8A),
            onError: const Color(0xFF3B0909),
            surface: const Color(0xFF0E1923),
            onSurface: const Color(0xFFE6EDF5),
            outlineVariant: const Color(0xFF2B3F50),
          );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF09121A) : background,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0E1923) : scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
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
        color: isDark ? const Color(0xFF16232E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 1 : 0.7),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF16232E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF101C26) : Colors.white,
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
        elevation: 3,
        backgroundColor: isDark ? const Color(0xFF0E1923) : scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 1 : 0.7),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return switch (status) {
      'available' => isDark ? const Color(0xFF56D99A) : AppTheme.success,
      'reserved' => isDark ? const Color(0xFFFFC857) : AppTheme.warning,
      'borrowed' => isDark ? const Color(0xFF8FC4F5) : AppTheme.blue,
      'maintenance' =>
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
      'retired' => scheme.outline,
      _ => scheme.outline,
    };
  }

  static Color forRequest(BuildContext context, String status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return switch (status) {
      'pending' => isDark ? const Color(0xFFFFC857) : AppTheme.warning,
      'approved' => isDark ? const Color(0xFF56D99A) : AppTheme.success,
      'released' => isDark ? const Color(0xFF8FC4F5) : AppTheme.blue,
      'returned' => isDark ? const Color(0xFF56D99A) : AppTheme.success,
      'completed' => isDark ? const Color(0xFF56D99A) : AppTheme.success,
      'overdue' => isDark ? const Color(0xFFFF8A8A) : AppTheme.danger,
      'rejected' => isDark ? const Color(0xFFFF8A8A) : AppTheme.danger,
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
        'completed' => Icons.task_alt_rounded,
        'overdue' => Icons.warning_amber_rounded,
        'rejected' => Icons.cancel_rounded,
        'cancelled' => Icons.remove_circle_outline_rounded,
        _ => Icons.help_rounded,
      };
}
