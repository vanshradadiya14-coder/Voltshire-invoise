import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../firebase/firebase_init.dart';
import 'constants/app_constants.dart';
import 'errors/error_boundary.dart';
import 'telemetry/telemetry.dart';

/// Everything that must happen before the first frame.
///
/// A release build that throws — or simply never returns — inside `main()`
/// before `runApp` draws no frame at all, so Android leaves the launch theme on
/// screen and the app appears frozen on its own icon, reporting nothing. That
/// is not a hypothetical: `Telemetry.initialise` is skipped entirely in debug,
/// so a platform channel that never answers in release is invisible until an
/// APK lands on a real phone.
///
/// Two rules follow from that:
///
///  * **Every step is time-limited.** A channel that never answers is a hang,
///    not an exception, so a `try`/`catch` around it catches nothing.
///  * **Only Firebase is allowed to stop the app.** Everything else degrades:
///    a missing crash reporter is worth less than a working app.
class Bootstrap {
  const Bootstrap._();

  /// Firebase is the one dependency the app genuinely cannot run without —
  /// every screen reads from Firestore. It needs no network to initialise, so
  /// exceeding this means something is wrong rather than slow.
  static const Duration _requiredLimit = Duration(seconds: 20);

  /// Optional steps get a shorter leash: the cost of skipping one is small,
  /// and the cost of waiting is a user staring at a motionless icon.
  static const Duration _optionalLimit = Duration(seconds: 8);

  /// Runs the startup sequence. Returns null when the app is safe to start.
  static Future<StartupFailure?> run() async {
    // Locale data so DateFormat works for en_GB (dd/MM/yyyy etc.). Failing
    // here only degrades formatting.
    await _optional('Loading date formats', () async {
      await initializeDateFormatting();
      Intl.defaultLocale = AppConstants.defaultLocale;
    });

    // Firebase + Firestore offline persistence.
    final StartupFailure? firebase = await _step(
      'Connecting to Firebase',
      FirebaseInit.ensureInitialized,
      _requiredLimit,
    );
    if (firebase != null) return firebase;

    // Crash reporting and analytics. Must come after Firebase, and must never
    // be load-bearing: this is the step that hung.
    await _optional('Starting crash reporting', Telemetry.initialise);

    // Replace the red screen of death with something a user can act on.
    ErrorBoundary.install();

    // Portrait-only: every screen is a single scrolling column, and landscape
    // buys nothing on a phone while doubling the layouts to verify.
    await _optional('Setting screen orientation', () {
      return SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });

    Telemetry.logEvent(AppEvent.appOpened);
    return null;
  }

  /// Runs one step, converting both a throw and a hang into a [StartupFailure].
  static Future<StartupFailure?> _step(
    String stage,
    Future<void> Function() action,
    Duration limit,
  ) async {
    try {
      await action().timeout(limit);
      return null;
    } on TimeoutException {
      return StartupFailure(stage: stage, error: 'no response', timedOut: true);
    } catch (error) {
      return StartupFailure(stage: stage, error: error, timedOut: false);
    }
  }

  /// Runs a step whose failure the app can live without.
  static Future<void> _optional(
    String stage,
    Future<void> Function() action,
  ) async {
    final StartupFailure? failure = await _step(stage, action, _optionalLimit);
    if (failure != null) {
      debugPrint('Startup: ${failure.detail} — continuing without it.');
    }
  }
}

/// Why startup stopped, in terms a user can read out over the phone.
@immutable
class StartupFailure {
  const StartupFailure({
    required this.stage,
    required this.error,
    required this.timedOut,
  });

  /// The step that failed, phrased for a person: 'Connecting to Firebase'.
  final String stage;
  final Object error;

  /// True when the step never answered, as opposed to failing outright. The
  /// two have completely different causes and deserve different wording.
  final bool timedOut;

  /// The line shown on the failure screen and, crucially, in a screenshot.
  String get detail =>
      timedOut ? '$stage: no response (timed out)' : '$stage: $error';
}
