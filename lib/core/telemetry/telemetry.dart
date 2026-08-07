import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting and product analytics.
///
/// Two rules govern everything in this file:
///
///  * **Never throw.** A telemetry failure must not become a user-visible
///    failure. Every method swallows its own errors.
///  * **Never log customer data.** Names, addresses, invoice line descriptions
///    and amounts stay on the device. Events carry counts and categories only,
///    which is what makes this safe under UK GDPR without a separate consent
///    flow for analytics.
class Telemetry {
  const Telemetry._();

  static bool _enabled = false;
  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;

  static FirebaseAnalytics? get analytics => _analytics;

  /// Wires up Crashlytics and Analytics. Called after `Firebase.initializeApp`.
  ///
  /// Disabled in debug builds: local stack traces are more useful in the
  /// console than in a dashboard, and debug noise pollutes release metrics.
  static Future<void> initialise({bool forceEnable = false}) async {
    if (kDebugMode && !forceEnable) {
      _enabled = false;
      return;
    }
    try {
      _crashlytics = FirebaseCrashlytics.instance;
      _analytics = FirebaseAnalytics.instance;

      await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      await _analytics!.setAnalyticsCollectionEnabled(true);

      // Route Flutter framework errors into Crashlytics.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _crashlytics!.recordFlutterFatalError(details);
      };

      // Catch errors from the platform/async layer that never reach Flutter.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _crashlytics!.recordError(error, stack, fatal: true);
        return true;
      };

      _enabled = true;
    } catch (e) {
      _enabled = false;
      debugPrint('Telemetry init failed: $e');
    }
  }

  /// Associates subsequent reports with a user. Only the Firebase UID is sent —
  /// never an email address.
  static Future<void> setUser(String? uid) async {
    if (!_enabled) return;
    try {
      await _crashlytics?.setUserIdentifier(uid ?? '');
      await _analytics?.setUserId(id: uid);
    } catch (_) {}
  }

  /// Records the subscription tier as a user property, so crash rates and
  /// funnels can be segmented by plan.
  static Future<void> setTier(String tier) async {
    if (!_enabled) return;
    try {
      await _analytics?.setUserProperty(name: 'subscription_tier', value: tier);
      await _crashlytics?.setCustomKey('tier', tier);
    } catch (_) {}
  }

  /// Reports a handled error — something recovered from, but worth knowing
  /// about. Repositories use this when a write fails.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_enabled) {
      debugPrint('Error${reason == null ? '' : ' ($reason)'}: $error');
      return;
    }
    try {
      await _crashlytics?.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {}
  }

  /// Adds a breadcrumb to the next crash report.
  static void log(String message) {
    if (!_enabled) {
      debugPrint(message);
      return;
    }
    try {
      _crashlytics?.log(message);
    } catch (_) {}
  }

  static Future<void> logEvent(AppEvent event,
      [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      await _analytics?.logEvent(name: event.name, parameters: params);
    } catch (_) {}
  }

  static Future<void> logScreen(String screenName) async {
    if (!_enabled) return;
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  // ---- Typed convenience events -----------------------------------------

  static Future<void> documentCreated(String type, {int lineItems = 0}) =>
      logEvent(AppEvent.documentCreated, <String, Object>{
        'type': type,
        'line_items': lineItems,
      });

  static Future<void> paymentRecorded(String method) =>
      logEvent(AppEvent.paymentRecorded, <String, Object>{'method': method});

  static Future<void> pdfShared(String type) =>
      logEvent(AppEvent.pdfShared, <String, Object>{'type': type});

  static Future<void> paywallShown(String source) =>
      logEvent(AppEvent.paywallShown, <String, Object>{'source': source});

  static Future<void> limitHit(String resource) =>
      logEvent(AppEvent.limitReached, <String, Object>{'resource': resource});

  static Future<void> purchaseCompleted(String tier, String period) =>
      logEvent(AppEvent.purchaseCompleted, <String, Object>{
        'tier': tier,
        'period': period,
      });

  static Future<void> purchaseFailed(String reason) =>
      logEvent(AppEvent.purchaseFailed, <String, Object>{'reason': reason});
}

/// Every analytics event the app emits.
///
/// An enum rather than string literals at call sites: a typo in a event name
/// produces a silently missing metric that nobody notices for months.
enum AppEvent {
  appOpened,
  signedUp,
  signedIn,
  setupCompleted,
  customerCreated,
  jobCreated,
  documentCreated,
  paymentRecorded,
  expenseRecorded,
  photoUploaded,
  pdfShared,
  quoteConverted,
  reportViewed,
  dashboardCustomised,
  dataExported,
  paywallShown,
  limitReached,
  purchaseCompleted,
  purchaseFailed,
  purchaseRestored,
}
