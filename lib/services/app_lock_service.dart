import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Optional biometric lock over the app.
///
/// This guards financial records on a device someone else might pick up. It is
/// explicitly *not* encryption — Firestore's local cache is protected by the
/// OS, and a determined attacker with the unlocked device is out of scope. The
/// honest framing is "a lock on the door", and the Settings copy says so.
class AppLockService {
  AppLockService(this._auth);

  final LocalAuthentication _auth;

  /// Whether the device can actually do biometrics or a device PIN.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Describes what the device offers, so Settings can say "Face ID" rather
  /// than the generic "biometrics".
  Future<String> describeAvailable() async {
    try {
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face unlock';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris)) return 'Iris';
      if (types.isNotEmpty) return 'Biometrics';
      return 'Device PIN';
    } catch (_) {
      return 'Device unlock';
    }
  }

  /// Prompts for authentication. Returns true when the user is verified.
  Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? 'Unlock Builder CRM',
        options: const AuthenticationOptions(
          // Falling back to the device PIN matters: a wet or dusty thumb is a
          // daily reality on a building site.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.prefBiometricLock) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefBiometricLock, value);
      if (value) await markUnlocked();
    } catch (_) {}
  }

  /// Records a successful unlock, starting the grace window.
  Future<void> markUnlocked() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        AppConstants.prefLastUnlockAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Whether a prompt is needed right now.
  ///
  /// A short grace period after the last unlock stops the app demanding a
  /// fingerprint every time the user flicks to the camera to photograph a
  /// receipt and comes straight back.
  Future<bool> shouldPrompt() async {
    if (!await isEnabled()) return false;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? last = prefs.getInt(AppConstants.prefLastUnlockAt);
      if (last == null) return true;
      final DateTime at = DateTime.fromMillisecondsSinceEpoch(last);
      return DateTime.now().difference(at) > AppConstants.appLockGrace;
    } catch (_) {
      return true;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(LocalAuthentication());
});

final appLockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(appLockServiceProvider).isEnabled();
});

final appLockSupportedProvider = FutureProvider<bool>((ref) {
  return ref.watch(appLockServiceProvider).isSupported();
});
