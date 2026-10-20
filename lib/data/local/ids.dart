import 'dart:math';

/// A random RFC-4122 version 4 identifier.
///
/// The app has no database generating UUIDs any more, so rows get their id
/// here. The format is kept identical to the old `gen_random_uuid()` output
/// so stored data, QR payloads and the models do not care where it came from.
String newLocalId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Version 4, variant 10xx.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final raw = bytes.map(hex).join();
  return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-'
      '${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
}
