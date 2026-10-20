import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local password storage.
///
/// There is no auth server any more, so credentials never leave the phone.
/// Passwords are still salted and hashed rather than stored in clear text:
/// the database file is readable on a rooted device, and a shared phone should
/// not hand the next person everybody's password.
///
/// SHA-256 with a random 16-byte salt is deliberate overkill for a barangay
/// kiosk but cheap enough to run on the UI thread once per sign-in.
class LocalPassword {
  const LocalPassword._();

  static String newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static bool verify(String password, String? salt, String? expectedHash) {
    if (salt == null ||
        expectedHash == null ||
        salt.isEmpty ||
        expectedHash.isEmpty) {
      return false;
    }
    return hash(password, salt) == expectedHash;
  }
}
