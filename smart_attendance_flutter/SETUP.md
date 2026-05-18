# Smart Attendance Flutter App – Setup Guide

## Step 1: Prerequisites

| Tool | Required Version | Download |
|---|---|---|
| Flutter SDK | ≥ 3.22.0 | https://flutter.dev/docs/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio |
| Android SDK | API 21+ (Android 5.0+) | Via Android Studio SDK Manager |
| Java JDK | 17 | Bundled with Android Studio |

---

## Step 2: Clone and setup

```powershell
# In your project folder
cd smart_attendance_flutter
flutter pub get
```

---

## Step 3: Connect a device or start an emulator

```powershell
# List available devices
flutter devices

# Run on connected Android device or emulator
flutter run
```

> **On first run**, Flutter auto-generates `android/local.properties` with
> the correct `flutter.sdk` and `sdk.dir` paths. You do NOT need to edit
> `local.properties` manually — just run `flutter run`.

---

## Step 4: Configure the backend URL

Edit `lib/core/constants/app_constants.dart`:

```dart
// Android Emulator → Django on localhost:
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

// Real Android device on same WiFi → replace with your PC's IP:
static const String baseUrl = 'http://192.168.X.X:8000/api/v1';

// Production server:
static const String baseUrl = 'https://your-domain.com/api/v1';
```

---

## Step 5: Start the Django backend

```bash
# In the smart_attendance (Django) folder:
python manage.py runserver 0.0.0.0:8000
```

---

## Common Issues & Fixes

### ❌ "Build failed due to use of deleted Android v1 embedding"
**Fix:** This version uses v2 embedding. Run:
```powershell
flutter clean
flutter pub get
flutter run
```

### ❌ "local.properties not found"
**Fix:** Run `flutter run` once from inside the `smart_attendance_flutter` folder.
Flutter auto-creates `android/local.properties`.

### ❌ Gradle download slow / fails
**Fix:** Set `distributionUrl` in `android/gradle/wrapper/gradle-wrapper.properties`
to a version you already have, or let Gradle download it (requires internet).

### ❌ Camera permission denied
**Fix:** On the physical device, go to Settings → Apps → Smart Attendance → Permissions
and enable Camera.

### ❌ "CLEARTEXT communication not permitted" (HTTP blocked on Android 9+)
**Fix:** For local dev, add to `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```
> ⚠️ Only for development. Use HTTPS in production.

---

## Build release APK

```powershell
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk
```

---

*Smart Attendance · UBa25EP188 · NAHPI, University of Bamenda · 2025*
