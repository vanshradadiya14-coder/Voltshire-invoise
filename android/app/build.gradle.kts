plugins {
    id("com.android.application")
    // Without this, google-services.json is never read, so Analytics and
    // Crashlytics find no google_app_id at process start and their native
    // auto-init silently does nothing - which is how a hang in
    // Telemetry.initialise reached a phone with no crash report to show for it.
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.builder_crm"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.builder_crm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Off deliberately. Firebase resolves its components by reflection
            // from names listed in the merged manifest, which is exactly the
            // pattern shrinkers break, and a stripped component surfaces as an
            // unreadable native crash on a phone rather than a build error.
            // This app is sideloaded for one business, so the ~15MB saved is
            // worth far less than never debugging R8 over a USB cable again.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
