# -----------------------------------------------------------------------------
# Builder CRM - Android setup
#
# This repo contains only Dart source, config and Firebase rules. The android/
# folder is generated rather than committed, so it has to be created once before
# the app can run on a device.
#
# This script does that, then applies every patch the build needs. Each patch is
# idempotent, so it is safe to re-run at any time.
#
#   Run from the project root:   powershell -ExecutionPolicy Bypass -File tools\setup_android.ps1
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

function Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "    OK   $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "    WARN $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "    FAIL $msg" -ForegroundColor Red }

# --- 0. Preflight ------------------------------------------------------------

Step "Checking your setup"

if (-not (Test-Path 'pubspec.yaml')) {
    Fail "Run this from the project root (the folder containing pubspec.yaml)."
    exit 1
}

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Fail "Flutter is not on your PATH."
    Write-Host ""
    Write-Host "  Install it first:  https://docs.flutter.dev/get-started/install/windows"
    Write-Host "  You need Flutter 3.32 or newer, plus Android Studio for the SDK."
    exit 1
}
Ok "Flutter found: $($flutter.Source)"

$version = (flutter --version 2>&1 | Select-Object -First 1)
Ok $version

# --- 1. Generate the Android project ----------------------------------------

Step "Generating the Android project"

if (Test-Path 'android') {
    Ok "android/ already exists - leaving it alone"
} else {
    flutter create --platforms=android .
    if ($LASTEXITCODE -ne 0) { Fail "flutter create failed"; exit 1 }
    Ok "android/ created"
}

# --- 2. SDK versions ---------------------------------------------------------
#
# Firebase requires minSdk 23. Several plugins need compileSdk 36. The NDK
# version is pinned because Firebase's native libraries are built against a
# specific one, and a mismatch produces a link error that reads like a bug in
# your own code.

Step "Setting SDK versions"

$appGradle = 'android\app\build.gradle.kts'
if (Test-Path $appGradle) {
    $c = Get-Content $appGradle -Raw

    # Match the whole line, not just the flutter.minSdkVersion placeholder -
    # if this script (or a previous run of it) already put a number here,
    # the narrower pattern silently no-ops and Firebase fails to compile.
    $c = $c -replace 'minSdk\s*=\s*[^\r\n]+',        'minSdk = 23'
    $c = $c -replace 'compileSdk\s*=\s*[^\r\n]+',    'compileSdk = 36'
    $c = $c -replace 'targetSdk\s*=\s*[^\r\n]+',     'targetSdk = 36'

    # 28.2.13676358 is the version several plugins (Firebase, purchases_flutter,
    # share_plus, sqflite_android, url_launcher_android, printing,
    # shared_preferences_android, package_info_plus) require as of their
    # current releases. NDKs are backward compatible, so pinning the highest
    # one any plugin needs satisfies all of them at once. If a future plugin
    # update demands a newer one, Gradle's error names the exact version to
    # put here.
    if ($c -match 'ndkVersion') {
        $c = $c -replace 'ndkVersion\s*=\s*[^\r\n]+', 'ndkVersion = "28.2.13676358"'
    } else {
        $c = $c -replace '(compileSdk\s*=\s*36)', "`$1`r`n    ndkVersion = `"28.2.13676358`""
    }

    Set-Content $appGradle $c -NoNewline
    Ok "minSdk 23, compileSdk/targetSdk 36, NDK 28.2.13676358"
} else {
    Warn "$appGradle not found - skipping (older Groovy template?)"
}

# Some plugins hardcode an older compileSdk of their own, so bumping the app
# alone is not enough. This forces every Android module to 36.
$projGradle = 'android\build.gradle.kts'
if ((Test-Path $projGradle) -and -not ((Get-Content $projGradle -Raw) -match 'androidExtension')) {
    Add-Content $projGradle @'

subprojects {
    if (!state.executed) {
        afterEvaluate {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
            }
        }
    }
}
'@
    Ok "forced compileSdk 36 across all plugin modules"
}

# --- 3. MainActivity ---------------------------------------------------------
#
# local_auth shows its biometric prompt from a FragmentActivity. The default
# template extends FlutterActivity, and leaving it produces a *runtime* crash
# the moment app lock is switched on - not a build error, so it is easy to ship
# broken.

Step "Enabling biometrics (FlutterFragmentActivity)"

$main = Get-ChildItem -Path 'android\app\src\main' -Filter 'MainActivity.kt' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
if ($main) {
    $c = Get-Content $main.FullName -Raw
    $c = $c -replace 'io\.flutter\.embedding\.android\.FlutterActivity', 'io.flutter.embedding.android.FlutterFragmentActivity'
    $c = $c -replace ':\s*FlutterActivity\(\)', ': FlutterFragmentActivity()'
    Set-Content $main.FullName $c -NoNewline
    Ok "MainActivity extends FlutterFragmentActivity"
} else {
    Warn "MainActivity.kt not found"
}

# --- 4. Manifest -------------------------------------------------------------

Step "Patching AndroidManifest.xml"

$manifest = 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
    $c = Get-Content $manifest -Raw

    # flutter create only puts INTERNET in the debug and profile manifests. A
    # release build without it cannot reach Firebase at all, and the failure
    # looks like a broken network rather than a missing permission.
    if ($c -notmatch 'android.permission.INTERNET') {
        $c = $c -replace '(<application)', @'
<uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    $1
'@
        Ok "added INTERNET, USE_BIOMETRIC, CAMERA, ACCESS_NETWORK_STATE"
    } else {
        Ok "permissions already present"
    }

    # Android 11+ package visibility. Without a <queries> block, url_launcher's
    # canLaunchUrl() returns false for tel:, mailto: and sms:, so "call
    # customer", "email invoice" and the payment-chase buttons silently do
    # nothing. This is the single most confusing Android gotcha in this app.
    if ($c -notmatch '<queries>') {
        $c = $c -replace '(</manifest>)', @'
<queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="mailto" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="smsto" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SEND" />
            <data android:mimeType="*/*" />
        </intent>
    </queries>
$1
'@
        Ok "added <queries> so call/email/SMS buttons work on Android 11+"
    } else {
        Ok "<queries> already present"
    }

    Set-Content $manifest $c -NoNewline
} else {
    Warn "$manifest not found"
}

# --- 5. Dependencies, icon and splash ---------------------------------------

Step "Installing dependencies"
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get failed"; exit 1 }
Ok "packages installed"

Step "Generating launcher icon and splash screen"
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { Warn "icon generation failed - the app will use the default Flutter icon" } else { Ok "launcher icon generated" }

dart run flutter_native_splash:create
if ($LASTEXITCODE -ne 0) { Warn "splash generation failed - not fatal" } else { Ok "splash screen generated" }

# --- 6. Devices --------------------------------------------------------------

Step "Looking for your phone"
flutter devices

Write-Host ""
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Setup complete." -ForegroundColor Cyan
Write-Host ""
Write-Host " If your phone is listed above:" -ForegroundColor Cyan
Write-Host "     flutter run"
Write-Host ""
Write-Host " If it is not, see RUN_ON_PHONE.md - it is almost always USB"
Write-Host " debugging being off, or the 'Allow debugging?' prompt on the"
Write-Host " phone not having been accepted yet."
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
