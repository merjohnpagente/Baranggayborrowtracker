/// Form validation shared by the login, registration, booking and profile
/// forms.
///
/// Every message is written for a resident to read on a phone in daylight,
/// and says what to do about it rather than naming the rule that was broken.
class Validators {
  const Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required.';
    // Deliberately simple: a full RFC 5322 pattern rejects addresses that
    // actually work. This catches the mistakes people make (missing @, spaces,
    // no domain) without turning away valid addresses.
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Accepts the Philippine mobile formats people actually type:
  /// `09171234567`, `+639171234567`, `9171234567`.
  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required.';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter a valid phone number (e.g. 0917 123 4567).';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required.';
    if (v.length < 2) return 'Enter your full name.';
    return null;
  }

  static String? purpose(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please state the purpose of this request.';
    if (v.length < 10) {
      return 'Add a little more detail (at least 10 characters).';
    }
    return null;
  }

  /// Asset codes are short and uppercase; this keeps a typo from creating an
  /// asset nobody can find later.
  static String? assetCode(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'Asset ID is required.';
    if (v.length < 3) return 'Use at least 3 characters.';
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(v)) {
      return 'Use letters, numbers and dashes only.';
    }
    return null;
  }

  static String? positiveInt(String? value, {String field = 'Quantity'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required.';
    final n = int.tryParse(v);
    if (n == null) return '$field must be a whole number.';
    if (n < 1) return '$field must be at least 1.';
    return null;
  }

  /// Rejects notes longer than the column; better a warning here than a
  /// database error after the user has filled in a whole form.
  static String? note(String? value, {int max = 500}) {
    final v = value?.trim() ?? '';
    if (v.length > max) return 'Please keep this under $max characters.';
    return null;
  }
}