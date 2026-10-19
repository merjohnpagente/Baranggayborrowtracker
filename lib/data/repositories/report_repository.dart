import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_summary.dart';

/// Reads the aggregate numbers behind the Reports screen.
class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  /// `dashboard_summary()` returns a single row (`returns table (...)`), which
  /// PostgREST serialises as a one-element array. Accept a map too, so a
  /// future change to a scalar-returning function does not break the screen.
  Future<DashboardSummary> fetchSummary() async {
    final data = await _client.rpc('dashboard_summary');
    if (data is List && data.isNotEmpty && data.first is Map) {
      return DashboardSummary.fromMap(
        Map<String, dynamic>.from(data.first as Map),
      );
    }
    if (data is Map) {
      return DashboardSummary.fromMap(Map<String, dynamic>.from(data));
    }
    throw const ReportException('The report could not be loaded.');
  }
}

class ReportException implements Exception {
  const ReportException(this.message);

  final String message;

  @override
  String toString() => message;
}
