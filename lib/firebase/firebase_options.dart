// Firebase configuration for the "voltshire" project.
//
// Android values are real (from the Firebase console). iOS/Web reuse the same
// project; if you later build for those platforms, regenerate this file with
// `flutterfire configure` to get their correct appIds.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkUxfg0_8J8IARLaXoM3DzbfPx284ZG0E',
    appId: '1:128975017290:android:1c8d46da504384ede45db3',
    messagingSenderId: '128975017290',
    projectId: 'voltshire',
    storageBucket: 'voltshire.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCkUxfg0_8J8IARLaXoM3DzbfPx284ZG0E',
    appId: '1:128975017290:android:1c8d46da504384ede45db3',
    messagingSenderId: '128975017290',
    projectId: 'voltshire',
    storageBucket: 'voltshire.firebasestorage.app',
    iosBundleId: 'com.example.builderCrm',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCkUxfg0_8J8IARLaXoM3DzbfPx284ZG0E',
    appId: '1:128975017290:android:1c8d46da504384ede45db3',
    messagingSenderId: '128975017290',
    projectId: 'voltshire',
    storageBucket: 'voltshire.firebasestorage.app',
    authDomain: 'voltshire.firebaseapp.com',
  );
}
