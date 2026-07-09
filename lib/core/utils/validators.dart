/// Reusable `TextFormField` validators. Each returns `null` when valid or an
/// error message string when invalid.
class Validators {
  const Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final RegExp regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  /// Email that is allowed to be empty (e.g. optional customer email).
  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? Function(String?) matches(String? other, {String message = 'Values do not match.'}) {
    return (String? value) => value == other ? null : message;
  }

  /// A positive number (used for quantity / price fields).
  static String? number(String? value, {String field = 'This field', bool allowZero = true}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    final double? parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < 0) return '$field cannot be negative.';
    if (!allowZero && parsed == 0) return '$field must be greater than zero.';
    return null;
  }

  /// A percentage 0–100.
  static String? percent(String? value) {
    if (value == null || value.trim().isEmpty) return null; // treated as 0
    final double? parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < 0 || parsed > 100) return 'Must be between 0 and 100.';
    return null;
  }
}

/// Small parsing helper: tolerant double parse that treats blank / bad input
/// as 0. Handy for live-calculating totals as the user types.
double parseNum(String? value) {
  if (value == null) return 0;
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}
