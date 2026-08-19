pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Reads android/app/google-services.json and injects the project
    // resources the Firebase Android SDKs auto-initialise from.
    id("com.google.gms.google-services") version "4.4.3" apply false
    // Required by firebase_crashlytics on Android. Without it the
    // Crashlytics component never registers, and because firebase_core
    // asks every registered plugin for its constants during
    // Firebase.initializeApp, that one missing component fails the whole
    // of Firebase - not just crash reporting.
    id("com.google.firebase.crashlytics") version "3.0.6" apply false
}

include(":app")
