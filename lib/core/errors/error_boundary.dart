import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../telemetry/telemetry.dart';
import 'app_exception.dart';

/// Replaces Flutter's red error screen with something a builder on a roof can
/// actually act on.
///
/// Install once in `main()`:
/// ```dart
/// ErrorBoundary.install();
/// ```
class ErrorBoundary {
  const ErrorBoundary._();

  static void install() {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // In debug, keep the red screen — it carries the stack trace and is
      // exactly what a developer wants to see.
      if (kDebugMode) return ErrorWidget(details.exception);
      return _FriendlyErrorWidget(details: details);
    };
  }
}

class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // This widget can be built outside a MaterialApp, so it cannot assume a
    // Theme, Directionality or Material ancestor exists.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFFCFCFD),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.warning_amber_rounded,
                    size: 44, color: Color(0xFFA9700A)),
                SizedBox(height: Insets.lg),
                Text(
                  "This part of the screen didn't load",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF20262E),
                  ),
                ),
                SizedBox(height: Insets.sm),
                Text(
                  'Your data is safe. Go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6470)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns any thrown object into a message worth showing a user, and reports it.
///
/// The default `error.toString()` on a Firestore permission failure reads
/// "[cloud_firestore/permission-denied] Missing or insufficient permissions",
/// which tells a builder nothing and looks like the app is broken.
class ErrorPresenter {
  const ErrorPresenter._();

  static String message(Object? error) {
    if (error == null) return 'Something went wrong.';

    if (error is AppException) return error.message;

    if (error is FirebaseAuthException) {
      return friendlyAuthMessage(error.code);
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'You do not have permission to do that. Try signing out and back in.',
        'unavailable' || 'network-request-failed' =>
          "Can't reach the server. Your changes are saved on this device and "
              'will sync when you are back online.',
        'not-found' => 'That record no longer exists.',
        'already-exists' => 'That record already exists.',
        'deadline-exceeded' => 'The request took too long. Please try again.',
        'resource-exhausted' =>
          'Too many requests right now. Please wait a moment.',
        'unauthenticated' => 'Please sign in again.',
        'cancelled' => 'The operation was cancelled.',
        _ => 'Something went wrong. Please try again.',
      };
    }

    if (error is StateError && error.message.contains('No authenticated user')) {
      return 'Please sign in again.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// True when the error is a transient connectivity problem — the caller can
  /// reassure rather than alarm.
  static bool isOffline(Object? error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'network-request-failed';
    }
    return false;
  }

  /// Reports and returns the presentable message in one call.
  static String report(Object error, StackTrace? stack, {String? context}) {
    Telemetry.recordError(error, stack, reason: context);
    return message(error);
  }
}
