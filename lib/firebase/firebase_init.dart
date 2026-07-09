import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Initialises Firebase and turns on Firestore offline persistence so the app
/// works without internet and syncs automatically when it returns.
///
/// Call once from `main()` before running the app.
class FirebaseInit {
  const FirebaseInit._();

  static Future<void> ensureInitialized() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Offline persistence: cache reads/writes locally and replay writes when
    // connectivity is restored. Enabled by default on mobile, but we set it
    // explicitly (and unbounded cache) for predictability across platforms.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (kIsWeb) {
      // Web needs explicit persistence enabling (best-effort — may fail in
      // multi-tab scenarios, which is safe to ignore).
      try {
        await FirebaseFirestore.instance
            .enablePersistence(const PersistenceSettings(synchronizeTabs: true));
      } catch (_) {
        // Persistence already enabled or unsupported in this context.
      }
    }
  }
}
