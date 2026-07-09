import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors/app_exception.dart';

/// Thin wrapper around [FirebaseAuth] that exposes a small, testable surface
/// and translates errors into [AppException]s.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Emits the current user (or null) whenever auth state changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Future<User> signIn({required String email, required String password}) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException(friendlyAuthMessage(e.code), code: e.code, cause: e);
    }
  }

  Future<User> register({required String email, required String password}) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException(friendlyAuthMessage(e.code), code: e.code, cause: e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException(friendlyAuthMessage(e.code), code: e.code, cause: e);
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> signOut() => _auth.signOut();
}
