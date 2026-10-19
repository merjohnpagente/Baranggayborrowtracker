import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/notification_item.dart';
import '../../state/notifications_provider.dart';

/// In-app inbox. Notifications are written by Postgres triggers, never by the
/// client, so this screen only reads them and stamps `read_at`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().load();
    });
  }

  Future<void> _open(NotificationItem item) async {
    await context.read<NotificationsProvider>().markRead(item.id);
    if (!mounted) return;
    final id = item.relatedRecordId;
    if (id == null) return;
    switch (item.relatedType) {
      case 'booking':
        context.push('/requests/$id');
      case 'asset':
        context.push('/assets/$id');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NotificationsProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: _body(theme, provider, items),
      ),
    );
  }

  Widget _body(
    ThemeData theme,
    NotificationsProvider provider,
    List<NotificationItem> items,
  ) {
    if (provider.loading && items.isEmpty) return const LoadingView();

    if (items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: provider.error ??
                  'Updates about your requests — approvals, due dates and '
                      'returns — will appear here.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: item.isUnread
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
              : null,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: _tintFor(item.type, theme).withValues(alpha: 0.14),
              child: Icon(
                _iconFor(item.type),
                size: 20,
                color: _tintFor(item.type, theme),
              ),
            ),
            title: Text(
              item.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: item.isUnread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.message != null && item.message!.isNotEmpty)
                    Text(
                      item.message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${Fmt.relative(item.createdAt)} · ${item.type.label}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            trailing: item.isUnread
                ? Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () => _open(item),
          ),
        );
      },
    );
  }

  IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.requestSubmitted => Icons.assignment_outlined,
        NotificationType.requestApproved => Icons.check_circle_outline_rounded,
        NotificationType.requestRejected => Icons.cancel_outlined,
        NotificationType.reservationApproaching =>
          Icons.event_available_outlined,
        NotificationType.returnDueSoon => Icons.schedule_rounded,
        NotificationType.overdueReturn => Icons.warning_amber_rounded,
        NotificationType.assetReturned => Icons.assignment_turned_in_outlined,
        NotificationType.maintenanceAlert => Icons.build_outlined,
      };

  Color _tintFor(NotificationType type, ThemeData theme) => switch (type) {
        NotificationType.requestApproved ||
        NotificationType.assetReturned =>
          const Color(0xFF169B62),
        NotificationType.requestRejected ||
        NotificationType.overdueReturn =>
          const Color(0xFFDC3545),
        NotificationType.returnDueSoon ||
        NotificationType.maintenanceAlert =>
          const Color(0xFFF59E0B),
        _ => theme.colorScheme.primary,
      };
}
