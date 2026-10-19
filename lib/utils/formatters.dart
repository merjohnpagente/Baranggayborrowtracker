import 'package:flutter/widgets.dart';

import '../models/booking.dart';
import '../models/transaction.dart';

/// Date/number formatting shared across screens.
///
/// Everything is `null`-tolerant on purpose: a booking read from a joined view
/// can arrive with a missing timestamp, and a formatter that throws on `null`
/// takes the whole list down with it.
class Formatters {
  const Formatters._();

  /// "May 12, 2025"
  static String date(DateTime? value) {
    if (value == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[value.month - 1];
    return '$m ${value.day}, ${value.year}';
  }

  /// "May 12, 2025 · 8:00 AM"
  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    return '${date(value)} · ${time(value)}';
  }

  /// "8:00 AM"
  static String time(DateTime? value) {
    if (value == null) return '—';
    final h = value.hour;
    final hour = h % 12 == 0 ? 12 : h % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = h < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  /// "May 12 – May 14, 2025", collapsing a shared month/year.
  static String dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '${date(start)} – ${date(end)}';
    if (start.year == end.year && start.month == end.month) {
      return '${date(start).replaceAll(', ${start.year}', '')} – '
          '${end.day}, ${end.year}';
    }
    if (start.year == end.year) {
      return '${date(start)} – ${date(end).replaceAll(', ${end.year}', '')}';
    }
    return '${date(start)} – ${date(end)}';
  }

  /// "in 2 days" / "3 hours ago" — for due-soon and overdue copy.
  static String relative(DateTime? value, {DateTime? now}) {
    if (value == null) return '—';
    final reference = now ?? DateTime.now();
    final diff = value.difference(reference);
    final future = diff.isPositive;
    final abs = diff.abs();

    String unit;
    if (abs.inMinutes < 1) {
      unit = 'just now';
    } else if (abs.inMinutes < 60) {
      unit = '${abs.inMinutes} min';
    } else if (abs.inHours < 24) {
      unit = '${abs.inHours} ${abs.inHours == 1 ? 'hour' : 'hours'}';
    } else if (abs.inDays < 30) {
      unit = '${abs.inDays} ${abs.inDays == 1 ? 'day' : 'days'}';
    } else if (abs.inDays < 365) {
      final months = (abs.inDays / 30).floor();
      unit = '$months ${months == 1 ? 'month' : 'months'}';
    } else {
      final years = (abs.inDays / 365).floor();
      unit = '$years ${years == 1 ? 'year' : 'years'}';
    }

    if (unit == 'just now') return unit;
    return future ? 'in $unit' : '$unit ago';
  }

  /// "ABC-123" style codes are always shown upper-case so a code read off a QR
  /// label matches what is on screen.
  static String code(String? value) =>
      (value == null || value.isEmpty) ? '—' : value.toUpperCase();
}

/// Icons for status badges, so every screen draws the same glyph for a state.
class StatusIcons {
  const StatusIcons._();

  static IconData booking(BookingStatus status) => status.icon;
  static IconData asset(String status) => AssetStatus.fromWire(status).icon;
}