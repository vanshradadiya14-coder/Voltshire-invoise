import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import 'core_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(firestoreProvider),
  );
});

/// Emits the Firebase [User] (or null) as auth state changes. This is the
/// root signal the router listens to for redirects.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The current signed-in UID, or null when signed out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// The `users/{uid}` profile document, used to gate the setup wizard.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<AppUser?>.value(null);
  return ref.watch(authRepositoryProvider).watchAppUser(uid);
});

/// Controller exposing auth actions to the UI, tracking a busy/error state.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo) : super(const AsyncValue<void>.data(null));

  final AuthRepository _repo;

  Future<bool> signIn(String email, String password) => _run(
        () => _repo.signIn(email, password),
      );

  Future<bool> register(String email, String password, {String displayName = ''}) =>
      _run(() => _repo.register(email, password, displayName: displayName));

  Future<bool> resetPassword(String email) => _run(
        () => _repo.sendPasswordReset(email),
      );

  Future<void> signOut() => _repo.signOut();

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue<void>.loading();
    try {
      await action();
      state = const AsyncValue<void>.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
