import 'package:intl/intl.dart';

/// Shared date / number formatting so every screen reads the same way.
class Fmt {
  const Fmt._();

  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _shortDate = DateFormat('MMM d');
  static final DateFormat _time = DateFormat('h:mm a');
  static final NumberFormat _peso =
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String shortDate(DateTime? value) =>
      value == null ? '—' : _shortDate.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : '${_date.format(value)} • ${_time.format(value)}';

  /// Short "how long ago" for notification rows.
  static String relative(DateTime? value) {
    if (value == null) return '—';
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }

  static String time(DateTime? value) =>
      value == null ? '—' : _time.format(value);

  static String peso(num? value) => _peso.format(value ?? 0);

  /// Inclusive day count: today → today is 1 day.
  static int inclusiveDays(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays + 1;
  }

  /// Human friendly countdown such as `in 3 days` or `2 days ago`.
  static String countdown(DateTime due) {
    final today = DateTime.now();
    final diff = DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'due today';
    if (diff == 1) return 'due tomorrow';
    if (diff > 1) return 'due in $diff days';
    if (diff == -1) return '1 day overdue';
    return '${diff.abs()} days overdue';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}