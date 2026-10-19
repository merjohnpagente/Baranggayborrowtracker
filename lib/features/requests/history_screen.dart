import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/request_card.dart';
import '../../data/models/borrow_request.dart';
import '../../data/repositories/borrow_repository.dart';
import '../../state/auth_provider.dart';

/// Finished requests: completed, declined and withdrawn.
///
/// RLS scopes the query — a resident sees their own rows, an official sees
/// every row — so the same screen serves both without a role branch.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _statuses = [
    RequestStatus.completed,
    RequestStatus.rejected,
    RequestStatus.cancelled,
  ];

  List<BorrowRequest> _items = const [];
  RequestStatus? _filter;
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
      final items = await context.read<BorrowRepository>().fetchHistory();
      if (!mounted) return;
      setState(() {
        _items = items;
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
    final isOfficial = context.select<AuthProvider, bool>((a) => a.isOfficial);
    final visible = _filter == null
        ? _items
        : _items.where((item) => item.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ..._statuses.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status.label),
                      selected: _filter == status,
                      onSelected: (selected) => setState(
                        () => _filter = selected ? status : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(visible, isOfficial),
      ),
    );
  }

  Widget _body(List<BorrowRequest> visible, bool isOfficial) {
    if (_loading && _items.isEmpty) return const LoadingView();

    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load the history',
              message: _error,
              action: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          ),
        ],
      );
    }

    if (visible.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyState(
              icon: Icons.history_rounded,
              title: _filter == null
                  ? 'No finished requests yet'
                  : 'No ${_filter!.label.toLowerCase()} requests',
              message: 'Completed, declined and withdrawn requests are kept '
                  'here for your records.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final request = visible[index];
        return RequestCard(
          request: request,
          showRequester: isOfficial,
          onTap: () => context.push('/requests/${request.id}'),
        );
      },
    );
  }
}
