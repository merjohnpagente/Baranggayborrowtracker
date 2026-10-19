import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_item.dart';

/// Reads and acknowledges `public.notifications`.
///
/// There is no insert method on purpose: notifications are written by database
/// triggers under `SECURITY DEFINER`, and the table has no INSERT policy, so a
/// client cannot fabricate one for somebody else.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<NotificationItem>> fetchMine({int limit = 100}) async {
    final uid = _uid;
    if (uid == null) return const [];
    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => NotificationItem.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// The RLS update policy already limits this to the caller's rows; the
  /// filter just avoids touching ones that are already read.
  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', uid)
        .filter('read_at', 'is', null);
  }
}
