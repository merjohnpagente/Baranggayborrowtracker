import '../local/local_store.dart';
import '../models/notification_item.dart';

/// Reads and acknowledges the local notification inbox.
///
/// Notifications are produced by the booking workflow (submitted, approved,
/// rejected, overdue), so they cannot be forged from a screen.
class NotificationRepository {
  NotificationRepository(this._store);

  final LocalStore _store;

  Future<List<NotificationItem>> fetchMine({int limit = 100}) async {
    final uid = _store.sessionUserId;
    if (uid == null) return const [];

    final rows = _store.notifications
        .where((row) => row['recipient_id'] == uid)
        .toList()
      ..sort((a, b) =>
          '${b['created_at']}'.compareTo('${a['created_at']}'));

    return rows
        .take(limit)
        .map(NotificationItem.fromMap)
        .toList();
  }

  Future<void> markRead(String id) async {
    final uid = _store.sessionUserId;
    if (uid == null) return;
    for (final row in _store.notifications) {
      if (row['id'] == id && row['recipient_id'] == uid) {
        row['read_at'] = _store.nowIso();
        await _store.save();
        return;
      }
    }
  }

  Future<void> markAllRead() async {
    final uid = _store.sessionUserId;
    if (uid == null) return;

    final now = _store.nowIso();
    var changed = false;
    for (final row in _store.notifications) {
      if (row['recipient_id'] != uid || row['read_at'] != null) continue;
      row['read_at'] = now;
      changed = true;
    }
    if (changed) await _store.save();
  }
}
