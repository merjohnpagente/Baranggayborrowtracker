import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/qr_payload.dart';
import '../../data/models/borrow_request.dart';
import '../../state/auth_provider.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/request_card.dart';
import '../qr/scanner_screen.dart';

/// Official queue: waiting for approval, plus everything currently out.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isOfficial) {
        context.read<RequestsProvider>().loadOfficialQueues();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<RequestsProvider>();

    if (!auth.isOfficial) {
      return Scaffold(
        appBar: AppBar(title: const Text('Approvals')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Officials only',
          message:
              'This queue is for barangay officials and administrators. Ask '
              'the barangay office to activate your account.',
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approvals'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<RequestsProvider>().loadOfficialQueues(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Waiting (${provider.pendingReviews.length})'),
              Tab(text: 'Out now (${provider.ongoing.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final raw = await scanQr(context);
            if (!context.mounted || raw == null) return;
            final payload = QrPayload.parse(raw);
            if (payload == null || payload.type != 'request') {
              AppToast.error(
                context,
                'Scan a request QR code to open its approval record.',
              );
              return;
            }
            context.push('/approvals/${payload.id}');
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan'),
        ),
        body: TabBarView(
          children: [
            _QueueList(
              requests: provider.pendingReviews,
              emptyIcon: Icons.inbox_rounded,
              emptyTitle: 'Queue is clear',
              emptyMessage: 'New requests from residents will appear here.',
              routePrefix: '/approvals',
              onRefresh: () =>
                  context.read<RequestsProvider>().loadOfficialQueues(),
            ),
            _QueueList(
              requests: provider.ongoing,
              emptyIcon: Icons.inventory_2_outlined,
              emptyTitle: 'Nothing out',
              emptyMessage:
                  'Approved and released items show here so you can track '
                  'returns.',
              routePrefix: '/approvals',
              onRefresh: () =>
                  context.read<RequestsProvider>().loadOfficialQueues(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.requests,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.routePrefix,
    required this.onRefresh,
  });

  final List<BorrowRequest> requests;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String routePrefix;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final request = requests[index];
          return AnimatedEntrance(
            key: ValueKey(request.id),
            delay: Motion.stagger(index),
            child: RequestCard(
              request: request,
              showRequester: true,
              onTap: () => context.push('$routePrefix/${request.id}'),
            ),
          );
        },
      ),
    );
  }
}