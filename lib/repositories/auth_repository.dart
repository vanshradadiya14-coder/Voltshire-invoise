import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Coordinates authentication with the `users` profile document.
///
/// On register/sign-in it ensures a `users/{uid}` document exists so the app
/// can track whether the Business Setup Wizard still needs to run.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final AuthService _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.uid;

  /// Streams the [AppUser] profile document for the current UID.
  Stream<AppUser?> watchAppUser(String uid) {
    return _userDoc(uid).snapshots().map((DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  Future<AppUser?> fetchAppUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _userDoc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<void> signIn(String email, String password) async {
    final User user = await _auth.signIn(email: email, password: password);
    await _ensureUserDoc(user);
    await _userDoc(user.uid).set(
      <String, dynamic>{'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> register(String email, String password, {String displayName = ''}) async {
    final User user = await _auth.register(email: email, password: password);
    if (displayName.isNotEmpty) {
      await _auth.updateDisplayName(displayName);
    }
    await _ensureUserDoc(user, displayName: displayName);
  }

  /// Creates the `users/{uid}` doc if it doesn't already exist.
  Future<void> _ensureUserDoc(User user, {String displayName = ''}) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _userDoc(user.uid).get();
    if (snap.exists) return;
    final AppUser profile = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName.isNotEmpty ? displayName : (user.displayName ?? ''),
      hasCompanyProfile: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    await _userDoc(user.uid).set(profile.toMap());
  }

  /// Marks that the company profile has been created (drives wizard gating).
  Future<void> markCompanyProfileComplete(String uid) async {
    await _userDoc(uid).set(
      <String, dynamic>{'hasCompanyProfile': true},
      SetOptions(merge: true),
    );
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);

  Future<void> signOut() => _auth.signOut();
}
