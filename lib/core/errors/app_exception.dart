/// A single, user-facing exception type used across the app.
///
/// Repositories and services translate low-level Firebase / platform errors
/// into an [AppException] carrying a friendly [message] the UI can display.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Human-readable message safe to show to the user.
  final String message;

  /// Optional machine-readable code (e.g. the Firebase error code).
  final String? code;

  /// The original error, kept for logging/debugging.
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

/// Maps common FirebaseAuth error codes to friendly messages.
String friendlyAuthMessage(String? code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'invalid-credential':
    case 'wrong-password':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Please choose a stronger password (at least 6 characters).';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
