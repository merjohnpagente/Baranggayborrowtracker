import 'package:flutter/foundation.dart';

import '../data/models/notification_item.dart';
import '../data/repositories/notification_repository.dart';

/// Unread count and the notification list, shared by the dashboard bell and
/// the notifications screen so the badge updates the moment a row is read.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._repository);

  final NotificationRepository _repository;

  List<NotificationItem> _items = const [];
  bool _loading = false;
  String? _error;

  List<NotificationItem> get items => _items;

  bool get loading => _loading;

  String? get error => _error;

  int get unreadCount => _items.where((item) => item.isUnread).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repository.fetchMine();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || !_items[index].isUnread) return;

    _items = [..._items]..[index] = _items[index].markedRead();
    notifyListeners();
    try {
      await _repository.markRead(id);
    } catch (_) {
      // The badge is already optimistic; a reload restores the truth.
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _items = _items.map((item) => item.markedRead()).toList();
    notifyListeners();
    try {
      await _repository.markAllRead();
    } catch (_) {
      // Leave the optimistic state; the next load reconciles it.
    }
  }
}
