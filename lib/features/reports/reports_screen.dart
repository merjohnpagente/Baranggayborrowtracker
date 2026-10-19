import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/dashboard_summary.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/auth_provider.dart';

/// Officials' live summary, straight from `dashboard_summary()`.
///
/// The numbers are computed by Postgres from the same rows the rest of the app
/// reads, so this cannot drift into a hand-maintained spreadsheet.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DashboardSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await context.read<ReportRepository>().fetchSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOfficial = context.select<AuthProvider, bool>((a) => a.isOfficial);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (isOfficial)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: !isOfficial
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Officials only',
              message: 'Barangay reports are available to staff, approvers and '
                  'administrators.',
            )
          : _loading && _summary == null
              ? const LoadingView()
              : _error != null && _summary == null
                  ? EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load the report',
                      message: _error,
                      action: FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConfig.barangayName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Live figures — generated '
                                    '${Fmt.dateTime(DateTime.now())}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SectionHeader(title: 'ASSETS'),
                          _grid(_summary!, theme),
                          const SectionHeader(title: 'WHAT THIS MEANS'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Every count is computed inside Postgres from '
                                'the current rows, the same ones the dashboard '
                                'and the approval queue read. Overdue returns '
                                'are swept into their own status by '
                                'mark_overdue_bookings(), so they are counted '
                                'here even before an officer opens the app.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _grid(DashboardSummary summary, ThemeData theme) {
    const success = Color(0xFF169B62);
    const warning = Color(0xFFF59E0B);
    const danger = Color(0xFFDC3545);
    final tiles = <Widget>[
      StatCard(
        label: 'Total assets',
        value: '${summary.totalAssets}',
        icon: Icons.inventory_2_rounded,
        color: theme.colorScheme.primary,
      ),
      StatCard(
        label: 'Available now',
        value: '${summary.availableAssets}',
        icon: Icons.check_circle_rounded,
        color: success,
      ),
      StatCard(
        label: 'Out with residents',
        value: '${summary.borrowedAssets}',
        icon: Icons.outbound_rounded,
        color: theme.colorScheme.secondary,
      ),
      StatCard(
        label: 'Pending requests',
        value: '${summary.pendingRequests}',
        icon: Icons.hourglass_top_rounded,
        color: warning,
      ),
      StatCard(
        label: 'Overdue returns',
        value: '${summary.overdueReturns}',
        icon: Icons.warning_amber_rounded,
        color: danger,
      ),
      StatCard(
        label: 'Starting in 7 days',
        value: '${summary.upcomingReservations}',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF6A1B9A),
      ),
      StatCard(
        label: 'In maintenance',
        value: '${summary.activeMaintenance}',
        icon: Icons.build_rounded,
        color: const Color(0xFF6D4C41),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: tiles,
    );
  }
}
