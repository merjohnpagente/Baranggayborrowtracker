import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/borrow_request.dart';
import '../../state/auth_provider.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/request_card.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  RequestStatus? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();
    final requests = _filter == null
        ? provider.mine
        : provider.mine.where((r) => r.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<RequestsProvider>().load(),
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
                ...RequestStatus.values.map(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<RequestsProvider>().refreshAll(
                isOfficial: context.read<AuthProvider>().isOfficial,
              );
        },
        child: provider.loading && provider.mine.isEmpty
            ? const LoadingView()
            : requests.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyState(
                          icon: Icons.assignment_outlined,
                          title: _filter == null
                              ? 'No requests yet'
                              : 'No ${_filter!.label.toLowerCase()} requests',
                          message: 'Request a vehicle, the court, the hall or any '
                              'barangay equipment.',
                          action: FilledButton.icon(
                            onPressed: () => context.push('/requests/new'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Make a request'),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return RequestCard(
                        request: request,
                        onTap: () => context.push('/requests/${request.id}'),
                      );
                    },
                  ),
      ),
    );
  }
}