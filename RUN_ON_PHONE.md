# Running Builder CRM on your phone over USB

This repo holds only the Dart source — the `android/` folder is generated, not
committed. So there is a one-time setup, then a one-line command every time
after that.

---

## Do I have what I need?

Open PowerShell in `D:\voltshire` and run:

```powershell
flutter doctor
```

**If that command isn't found**, install Flutter first — allow about 30 minutes:

1. Flutter SDK — <https://docs.flutter.dev/get-started/install/windows>
   (unzip to something like `C:\src\flutter`, add `C:\src\flutter\bin` to PATH)
2. Android Studio — <https://developer.android.com/studio>
   During setup let it install the **Android SDK** and **SDK Platform-Tools**
3. Accept the SDK licences:
   ```powershell
   flutter doctor --android-licenses
   ```

You need green ticks next to **Flutter** and **Android toolchain**. Ignore any
warnings about Visual Studio, Chrome or Xcode — none of those matter here.

---

## One-time setup

```powershell
cd D:\voltshire
powershell -ExecutionPolicy Bypass -File tools\setup_android.ps1
```

That script generates the Android project and applies five patches the build
needs. Each one is here because leaving it out fails in a way that is hard to
diagnose:

| Patch | Why |
|---|---|
| `minSdk 23` | Firebase won't compile below it |
| `compileSdk 36` + forced across plugins | Some plugins pin an older SDK of their own |
| Pinned NDK version | A mismatch produces a link error that reads like a bug in your code |
| `MainActivity` → `FlutterFragmentActivity` | `local_auth` needs it. Without it the app **builds fine** and crashes when app lock is turned on |
| `INTERNET` in the main manifest | `flutter create` only adds it to debug/profile. A release build can't reach Firebase and it looks like a broken network |
| `<queries>` block | Android 11+ package visibility. Without it `canLaunchUrl` returns false, so **call**, **email** and **chase payment** silently do nothing |

Re-running the script is safe — every patch checks itself first.

---

## Prepare the phone

1. **Settings → About phone → tap "Build number" seven times**
   You'll see "You are now a developer".
2. **Settings → System → Developer options → turn on USB debugging**
3. Plug the phone into the PC with a USB cable.
4. On the phone, tap **Allow** on the *"Allow USB debugging?"* prompt.
   Tick *"Always allow from this computer"* so you don't see it every time.

> Use the cable that came with the phone if you can. A lot of cheap cables are
> charge-only and carry no data — the phone charges, and nothing else happens.
> This is the most common reason a device never shows up.

Check it worked:

```powershell
flutter devices
```

Your phone should be listed by name.

---

## Run it

```powershell
flutter run
```

First build takes 3–10 minutes — Gradle is downloading the Android toolchain.
After that it's seconds.

While it's running:

| Key | Does |
|---|---|
| `r` | Hot reload — your change appears without losing app state |
| `R` | Hot restart — full restart, state cleared |
| `q` | Quit |

---

## Installing it properly (no cable, stays on the phone)

`flutter run` installs a debug build that's slower and stops when you unplug.
For a real installable app:

```powershell
flutter build apk --release
```

The file lands at:

```
build\app\outputs\flutter-apk\app-release.apk
```

Copy it to the phone and open it, or install over USB:

```powershell
flutter install --release
```

Android will warn about installing from an unknown source — that's expected for
an app that hasn't been through the Play Store.

> **Subscriptions won't work in this build.** Without a RevenueCat key the app
> falls back to its mock billing service and everyone gets the Free tier. That's
> deliberate — it never crashes on missing config. To test real purchases:
> ```powershell
> flutter build apk --release --dart-define=REVENUECAT_ANDROID_KEY=goog_xxxxx
> ```

---

## When it doesn't work

**Phone doesn't appear in `flutter devices`**

Work through these in order — it's nearly always one of the first two:

1. Try a different USB cable (charge-only cables are extremely common)
2. Re-accept the debugging prompt: turn USB debugging off and on again, unplug,
   replug, and watch the phone screen for the dialog
3. Pull down the notification shade → tap the USB notification → set it to
   **File transfer / MTP** rather than "Charging only"
4. Check the raw connection:
   ```powershell
   adb devices
   ```
   * empty list → the PC can't see the phone at all (cable, port, or driver)
   * `unauthorized` → the prompt on the phone hasn't been accepted
   * `device` → it's fine, and the problem is Flutter's config not the cable
5. Samsung, Xiaomi and a few others need the manufacturer's USB driver on
   Windows. Search "*&lt;your phone brand&gt;* USB driver windows".

**`flutter doctor` complains about Android licences**

```powershell
flutter doctor --android-licenses
```
Press `y` at each prompt.

**Gradle fails on the first build**

Usually a half-downloaded cache. Clear it and retry:

```powershell
flutter clean
flutter pub get
flutter run
```

**"Minimum supported Gradle version" or an NDK error**

Re-run the setup script — it pins both:

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup_android.ps1
```

**App installs but shows a blank screen or closes immediately**

Watch the log while it happens:

```powershell
flutter run --verbose
```

The most likely cause is Firebase. Check in the
[Firebase console](https://console.firebase.google.com/) for project
**voltshire** that:

* **Authentication → Sign-in method → Email/Password** is enabled
* **Firestore Database** exists
* **Storage** is enabled

Then deploy the rules, or every read will be denied:

```powershell
npm install -g firebase-tools
firebase login
firebase use voltshire
firebase deploy --only firestore:rules,firestore:indexes,storage
```

**Can't sign in / everything is empty after signing in**

That's the rules not being deployed. Run the `firebase deploy` above.

**Sign-in fails with "API key not valid" or a 403**

`flutter create` names the app `com.example.builder_crm`. The app talks to
Firebase using the values baked into `lib/firebase/firebase_options.dart`, so a
package-name mismatch is usually harmless — but it will bite if that API key has
been restricted to a specific Android app in Google Cloud.

Two ways out. Either loosen the key:

> Google Cloud Console → APIs & Services → Credentials → your Android key →
> **Application restrictions: None** (fine for testing)

…or make the package name match what's registered in Firebase. Check the
registered name under Firebase console → Project settings → Your apps, then set
it in `android/app/build.gradle.kts`:

```kotlin
applicationId = "the.registered.package.name"
```

Changing `applicationId` after installing means the old app stays on the phone
as a separate icon — uninstall it to avoid confusion.

---

## Day to day

Once set up, this is the whole loop:

```powershell
cd D:\voltshire
flutter run
```

Edit a file, press `r`, see it on the phone.
