import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/qr_payload.dart';
import '../../data/models/asset.dart';
import '../../data/models/borrow_request.dart';
import '../../state/auth_provider.dart';
import '../../state/inventory_provider.dart';
import '../../state/notifications_provider.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/request_card.dart';
import '../qr/scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final inventory = context.read<InventoryProvider>();
    final requests = context.read<RequestsProvider>();
    await Future.wait([
      inventory.load(),
      requests.load(),
      context.read<NotificationsProvider>().load(),
      if (auth.isOfficial) requests.loadOfficialQueues(),
    ]);
  }

  Future<void> _scan() async {
    final raw = await scanQr(context);
    if (!mounted || raw == null) return;
    final payload = QrPayload.parse(raw);
    if (payload == null) {
      AppToast.error(context, 'That QR code is not a Barangay Borrow Tracker code.');
      return;
    }
    switch (payload.type) {
      case 'asset':
        final asset = await context
            .read<InventoryProvider>()
            .lookupByCode(payload.id);
        if (!mounted) return;
        if (asset == null) {
          AppToast.error(context, 'Asset ${payload.id} was not found.');
        } else {
          context.push('/assets/${asset.id}');
        }
      case 'request':
        final request = await context.read<RequestsProvider>().fetchById(payload.id);
        if (!mounted) return;
        if (request == null) {
          AppToast.error(context, 'That request record was not found.');
        } else {
          context.push('/requests/${request.id}');
        }
      default:
        AppToast.error(context, 'Unsupported QR code type.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final requests = context.watch<RequestsProvider>();
    final notifications = context.watch<NotificationsProvider>();
    final upcoming = requests.upcomingMine.take(3).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<InventoryProvider>().refresh(),
            context
                .read<RequestsProvider>()
                .refreshAll(isOfficial: auth.isOfficial),
            context.read<NotificationsProvider>().load(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConfig.barangayName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _greeting(auth.profile?.fullName ?? ''),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: notifications.unreadCount > 0,
                    label: Text('${notifications.unreadCount}'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'My profile',
                  onPressed: () => context.go('/profile'),
                  icon: auth.profile == null
                      ? const Icon(Icons.person_rounded)
                      : UserAvatar(profile: auth.profile!, radius: 16),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatGrid(),
                  if (auth.isOfficial) ...[
                    const SectionHeader(title: 'OFFICIAL TOOLS'),
                    AnimatedEntrance(
                      delay: Motion.stagger(1, stepMs: 70),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Scan QR',
                              onTap: _scan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.fact_check_rounded,
                              label: 'Approvals',
                              badge: requests.pendingReviews.isEmpty
                                  ? null
                                  : '${requests.pendingReviews.length}',
                              onTap: () => context.go('/approvals'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedEntrance(
                      delay: Motion.stagger(2, stepMs: 70),
                      child: _ActionTile(
                        icon: Icons.bar_chart_rounded,
                        label: 'Reports & statistics',
                        onTap: () => context.push('/reports'),
                      ),
                    ),
                  ],
                  SectionHeader(
                    title: 'MY ACTIVE LOANS',
                    actionLabel: 'View all',
                    onAction: () => context.go('/requests'),
                  ),
                  if (upcoming.isEmpty)
                    _InfoBanner(
                      icon: Icons.check_circle_outline_rounded,
                      text: 'You have no items out right now. '
                          'Browse the catalogue to request one.',
                      actionLabel: 'Browse assets',
                      onAction: () => context.go('/assets'),
                    )
                  else
                    ...upcoming.asMap().entries.map(
                      (entry) {
                        final request = entry.value;
                        return AnimatedEntrance(
                          key: ValueKey('dashboard-request-${request.id}'),
                          delay: Motion.stagger(entry.key + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RequestCard(
                              request: request,
                              onTap: () =>
                                  context.push('/requests/${request.id}'),
                            ),
                          ),
                        );
                      },
                    ),
                  if (requests.overdueMine.isNotEmpty) ...[
                    const SectionHeader(title: 'NEEDS ATTENTION'),
                    ...requests.overdueMine.asMap().entries.map(
                      (entry) {
                        final request = entry.value;
                        return AnimatedEntrance(
                          key: ValueKey('dashboard-overdue-${request.id}'),
                          delay: Motion.stagger(entry.key + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RequestCard(
                              request: request,
                              onTap: () =>
                                  context.push('/requests/${request.id}'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (auth.isOfficial &&
                      requests.pendingReviews.isNotEmpty) ...[
                    SectionHeader(
                      title: 'WAITING FOR YOUR DECISION',
                      actionLabel: 'Open queue',
                      onAction: () => context.go('/approvals'),
                    ),
                    ...requests.pendingReviews.take(3).toList().asMap().entries.map(
                          (entry) {
                            final request = entry.value;
                            return AnimatedEntrance(
                              key: ValueKey(
                                'dashboard-review-${request.id}',
                              ),
                              delay: Motion.stagger(entry.key + 1),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RequestCard(
                                  request: request,
                                  showRequester: true,
                                  onTap: () => context.push(
                                    '/approvals/${request.id}',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ],
                  const SectionHeader(title: 'AVAILABLE NOW'),
                  ..._availableAssets(inventory),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request'),
      ),
    );
  }

  List<Widget> _availableAssets(InventoryProvider inventory) {
    if (inventory.loading && inventory.assets.isEmpty) {
      return const [LoadingView()];
    }
    final available = inventory.assets
        .where((asset) => asset.status == AssetStatus.available)
        .take(3)
        .toList();
    if (available.isEmpty) {
      return const [
        _InfoBanner(
          icon: Icons.inventory_2_outlined,
          text: 'No assets are marked available at the moment.',
        ),
      ];
    }
    return [
      ...available.asMap().entries.map(
        (entry) {
          final asset = entry.value;
          return AnimatedEntrance(
            key: ValueKey('available-${asset.id}'),
            delay: Motion.stagger(entry.key + 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AssetCard(
                asset: asset,
                onTap: () => context.push('/assets/${asset.id}'),
              ),
            ),
          );
        },
      ),
      AnimatedEntrance(
        delay: Motion.stagger(available.length + 1),
        child: OutlinedButton.icon(
          onPressed: () => context.go('/assets'),
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('See the full catalogue'),
        ),
      ),
    ];
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    if (name.trim().isEmpty) return part;
    return '$part, ${name.trim().split(' ').first}';
  }
}

class _StatGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final requests = context.watch<RequestsProvider>();
    final auth = context.watch<AuthProvider>();

    final stats = <Widget>[
      StatCard(
        label: 'Assets available',
        value: '${inventory.availableCount}',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF2E7D32),
        onTap: () => context.go('/assets'),
      ),
      StatCard(
        label: 'Out with me',
        value: '${requests.activeMine.length}',
        icon: Icons.outbound_rounded,
        color: const Color(0xFF1565C0),
        onTap: () => context.go('/requests'),
      ),
      StatCard(
        label: 'Pending requests',
        value: '${requests.mine.where((r) => r.status == RequestStatus.pending).length}',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF9A825),
        onTap: () => context.go('/requests'),
      ),
      if (auth.isOfficial)
        StatCard(
          label: 'To review',
          value: '${requests.pendingReviews.length}',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF6A1B9A),
          onTap: () => context.go('/approvals'),
        )
      else
        StatCard(
          label: 'Overdue',
          value: '${requests.overdueMine.length}',
          icon: Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          onTap: () => context.go('/requests'),
        ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (var i = 0; i < stats.length; i++)
          AnimatedEntrance(
            key: ValueKey('dashboard-stat-$i'),
            delay: Motion.stagger(i, stepMs: 55),
            offset: const Offset(0, 0.08),
            child: stats[i],
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}