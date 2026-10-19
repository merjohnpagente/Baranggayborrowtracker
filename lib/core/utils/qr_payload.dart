/// Tiny helper for the QR codes printed on stickers and shown at handover.
///
/// Format: `BBT|<type>|<uuid>` so a scan can be routed without a network
/// round trip, and a sticker stays valid even if the app is offline.
class QrPayload {
  const QrPayload._();

  static const String _prefix = 'BBT';

  static String forAsset(String assetId) => '$_prefix|asset|$assetId';

  static String forRequest(String requestId) => '$_prefix|request|$requestId';

  static ({String type, String id})? parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split('|');
    if (parts.length != 3 || parts.first != _prefix) return null;
    return (type: parts[1], id: parts[2]);
  }

  /// Human readable text printed under the QR image.
  static String caption(String payload) {
    final parsed = parse(payload);
    if (parsed == null) return payload;
    return parsed.id.toUpperCase();
  }
}