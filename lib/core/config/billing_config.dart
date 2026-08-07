import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time billing configuration.
///
/// Keys are supplied with `--dart-define` so they never enter source control:
///
/// ```
/// flutter build apk --release \
///   --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///   --dart-define=REVENUECAT_IOS_KEY=appl_xxx
/// ```
///
/// RevenueCat public SDK keys are safe to ship in a client binary — they can
/// only read offerings and start purchases, never issue entitlements. The
/// secret key must stay server-side and is not referenced anywhere here.
class BillingConfig {
  const BillingConfig._();

  static const String androidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  static const String iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  /// The RevenueCat offering to display. Leave as `current` unless running an
  /// A/B test on pricing from the RevenueCat dashboard.
  static const String offeringId =
      String.fromEnvironment('REVENUECAT_OFFERING', defaultValue: 'current');

  /// Returns the key for the running platform, or null when billing is not
  /// configured or the platform has no store.
  static String? apiKeyForPlatform() {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) return androidKey.isEmpty ? null : androidKey;
      if (Platform.isIOS) return iosKey.isEmpty ? null : iosKey;
    } catch (_) {
      return null;
    }
    return null;
  }

  /// True when a key is present for this platform. Used to decide between the
  /// real service and the mock at composition time.
  static bool get isConfigured => apiKeyForPlatform() != null;

  /// Length of the introductory trial advertised in the UI. The store product
  /// is authoritative; this is only the fallback copy shown before offerings
  /// have loaded.
  static const int advertisedTrialDays = 14;

  /// Where "Manage subscription" sends users when the store did not supply a
  /// management URL.
  static const String playManageUrl =
      'https://play.google.com/store/account/subscriptions';
  static const String appStoreManageUrl =
      'https://apps.apple.com/account/subscriptions';

  /// Support contact surfaced on the paywall and in billing error states.
  static const String supportEmail = 'support@buildercrm.app';

  static const String termsUrl = 'https://buildercrm.app/terms';
  static const String privacyUrl = 'https://buildercrm.app/privacy';
}
