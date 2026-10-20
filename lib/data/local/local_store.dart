import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'ids.dart';
import 'seed_data.dart';

/// The whole database, in one JSON file inside the app's private storage.
///
/// Why a JSON file instead of SQLite: the app's data is a handful of lists and
/// every query it needs is a filter over one of them. A file keeps the app
/// dependency-light, makes a backup a single file, and — unlike
/// `shared_preferences` — has no practical size ceiling once photos are stored
/// beside it.
///
/// Photos are *not* base64 in the JSON. They are written as ordinary files in
/// `photos/` and the asset row stores their absolute path, so the database
/// stays small and images load without decoding a megabyte string first.
///
/// There is no server and no user isolation beyond the sign-in screen: this is
/// a barangay kiosk, not a multi-tenant service. The password hash protects
/// against a casual glance, not against somebody with root access to the phone.
class LocalStore {
  LocalStore._(this._file, this._data);

  static const int schemaVersion = 1;

  static const List<String> _tables = [
    'profiles',
    'assets',
    'bookings',
    'transactions',
    'notifications',
  ];

  final File _file;
  final Map<String, dynamic> _data;

  /// Writes are chained so two quick saves cannot interleave and leave a
  /// half-written file behind.
  Future<void> _writes = Future<void>.value();

  static Future<LocalStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/barangay_borrow_tracker');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    final file = File('${folder.path}/database.json');

    Map<String, dynamic> data;
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        data = decoded is Map<String, dynamic>
            ? decoded
            : seedDatabase();
      } catch (_) {
        // A corrupt file must not brick the app. The old file is kept on disk
        // by save()'s rename, so nothing is silently destroyed beyond this run.
        data = seedDatabase();
      }
    } else {
      data = seedDatabase();
    }

    final store = LocalStore._(file, data);
    store._ensureShape();
    await store.save();
    return store;
  }

  /// The path of the JSON file, for diagnostics in Settings.
  String get databasePath => _file.path;

  Directory get photoDirectory {
    final directory = Directory('${_file.parent.path}/photos');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  void _ensureShape() {
    _data['version'] ??= schemaVersion;
    _data['session_user_id'] ??= null;
    for (final table in _tables) {
      final value = _data[table];
      if (value is! List) {
        _data[table] = <Map<String, dynamic>>[];
      }
    }
  }

  // ---- Table access --------------------------------------------------------

  /// Live list — callers mutate rows and then [save]. Returning copies would
  /// make every repository forget to write its change back.
  List<Map<String, dynamic>> table(String name) {
    final value = _data[name];
    if (value is List) {
      for (var index = 0; index < value.length; index++) {
        final row = value[index];
        if (row is! Map<String, dynamic>) {
          value[index] = Map<String, dynamic>.from(row as Map);
        }
      }
      return value.cast<Map<String, dynamic>>();
    }
    final fresh = <Map<String, dynamic>>[];
    _data[name] = fresh;
    return fresh;
  }

  List<Map<String, dynamic>> get profiles => table('profiles');
  List<Map<String, dynamic>> get assets => table('assets');
  List<Map<String, dynamic>> get bookings => table('bookings');
  List<Map<String, dynamic>> get transactions => table('transactions');
  List<Map<String, dynamic>> get notifications => table('notifications');

  Map<String, dynamic>? _byId(
    List<Map<String, dynamic>> rows,
    String? id,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  Map<String, dynamic>? profileById(String? id) => _byId(profiles, id);

  Map<String, dynamic>? assetById(String? id) => _byId(assets, id);

  Map<String, dynamic>? bookingById(String? id) => _byId(bookings, id);

  Map<String, dynamic>? transactionForBooking(String? bookingId) {
    for (final row in transactions) {
      if (row['booking_id'] == bookingId) return row;
    }
    return null;
  }

  Map<String, dynamic>? profileByEmail(String email) {
    final needle = email.trim().toLowerCase();
    for (final row in profiles) {
      if ((row['email'] as String?)?.toLowerCase() == needle) return row;
    }
    return null;
  }

  String? get sessionUserId => _data['session_user_id'] as String?;

  Map<String, dynamic>? get currentProfile => profileById(sessionUserId);

  Future<void> setSession(String? userId) {
    _data['session_user_id'] = userId;
    return save();
  }

  // ---- Availability --------------------------------------------------------

  bool blocksAvailability(String? status) =>
      status == 'approved' || status == 'released' || status == 'overdue';

  /// Whether [assetId] is free for the half-open window `[start, end)`.
  ///
  /// Same rule the old `check_asset_availability` used: confirmed bookings
  /// only, and back-to-back slots are allowed because the interval is
  /// half-open.
  bool isAssetAvailable(
    String assetId,
    DateTime start,
    DateTime end, {
    String? exceptBookingId,
  }) {
    for (final booking in bookings) {
      if (booking['asset_id'] != assetId) continue;
      if (booking['id'] == exceptBookingId) continue;
      if (!blocksAvailability(booking['status'] as String?)) continue;
      final otherStart = DateTime.tryParse('${booking['start_time']}');
      final otherEnd = DateTime.tryParse('${booking['end_time']}');
      if (otherStart == null || otherEnd == null) continue;
      if (otherStart.isBefore(end) && otherEnd.isAfter(start)) {
        return false;
      }
    }
    return true;
  }

  /// Recomputes `assets.status` from the bookings, like the old
  /// `refresh_asset_status()` trigger did.
  ///
  /// Maintenance and retired are manual overrides and are left alone.
  void refreshAssetStatus(String assetId) {
    final asset = assetById(assetId);
    if (asset == null) return;
    final current = asset['status'] as String?;
    if (current == 'maintenance' || current == 'retired') return;

    var status = 'available';
    for (final booking in bookings) {
      if (booking['asset_id'] != assetId) continue;
      final bookingStatus = booking['status'];
      if (bookingStatus == 'released' || bookingStatus == 'overdue') {
        status = 'borrowed';
        break;
      }
      if (bookingStatus == 'approved') {
        status = 'reserved';
      }
    }
    asset['status'] = status;
    asset['updated_at'] = nowIso();
  }

  void refreshAllAssetStatuses() {
    for (final asset in assets) {
      refreshAssetStatus(asset['id'] as String);
    }
  }

  // ---- Writes --------------------------------------------------------------

  String newRequestId() {
    final year = DateTime.now().year;
    final prefix = 'BRGY-$year-';
    var highest = 0;
    for (final booking in bookings) {
      final reference = booking['request_id'] as String? ?? '';
      if (!reference.startsWith(prefix)) continue;
      final number = int.tryParse(reference.substring(prefix.length));
      if (number != null && number > highest) highest = number;
    }
    return '$prefix${(highest + 1).toString().padLeft(4, '0')}';
  }

  void addNotification({
    required String recipientId,
    required String title,
    String? message,
    required String type,
    String? relatedRecordId,
    String relatedType = 'booking',
  }) {
    notifications.add({
      'id': newLocalId(),
      'recipient_id': recipientId,
      'title': title,
      'message': message,
      'related_record_id': relatedRecordId,
      'related_type': relatedType,
      'type': type,
      'read_at': null,
      'created_at': nowIso(),
    });
  }

  Future<String> savePhoto(Uint8List bytes, String fileName) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${photoDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Removes a photo that is no longer referenced by any asset.
  Future<void> deletePhotoIfUnused(String path) async {
    if (!path.startsWith('/')) return; // a bundled/legacy URL, not ours
    for (final asset in assets) {
      final urls = asset['image_urls'];
      if (urls is List && urls.contains(path)) return;
    }
    final file = File(path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {
        // A locked or already-missing file is not worth failing a save over.
      }
    }
  }

  String nowIso() => DateTime.now().toUtc().toIso8601String();

  Future<void> save() {
    final snapshot = jsonEncode(_data);
    final write = _writes.catchError((_) {}).then((_) async {
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(snapshot, flush: true);
      await temporary.rename(_file.path);
    });
    // Keep the chain alive even when this write fails; the caller still gets
    // the original error from [write].
    _writes = write.catchError((_) {});
    return write;
  }
}
