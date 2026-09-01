# Civilsalt Attendance – Flutter Mobile Application

**Design and Implementation of an Offline-Capable Smart Attendance System Using QR Codes and Secure Synchronisation**

> Master of Engineering – Computer Engineering  
> Civilsalt · Attendance Crisis Solution  
> **Author:** Buhnyuy Ronald Yika · Registration No. UBa25EP188  
> **Supervisor:** Dr. M. Nsangou Mouchili  
> **Field Supervisor:** Engr. N Titus

---

## Architecture – MVC + Provider

```
lib/
├── main.dart                        ← App entry point, routing, DI
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart       ← API URLs, keys, route names
│   │   └── app_theme.dart           ← Material 3 theme, colors, gradients
│   ├── network/
│   │   ├── api_client.dart          ← Dio HTTP client with JWT interceptor
│   │   └── api_result.dart          ← Generic result type (success/failure)
│   ├── database/
│   │   └── database_helper.dart     ← SQLite setup, schema, CRUD helpers
│   └── utils/
│       ├── qr_utils.dart            ← HMAC-SHA256 QR generation & verification
│       ├── connectivity_service.dart ← Real-time network monitoring
│       └── secure_storage_service.dart ← JWT/UUID encrypted storage
│
├── models/                          ← MODEL layer (pure data classes)
│   ├── user_model.dart
│   ├── course_model.dart
│   ├── session_model.dart
│   └── attendance_record_model.dart
│
├── services/                        ← Data access (API + SQLite)
│   ├── auth_service.dart
│   ├── course_service.dart
│   ├── session_service.dart
│   └── attendance_service.dart
│
├── controllers/                     ← CONTROLLER layer (ChangeNotifier)
│   ├── auth_controller.dart
│   ├── course_controller.dart
│   ├── session_controller.dart
│   └── attendance_controller.dart
│
└── views/                           ← VIEW layer (Flutter widgets)
    ├── auth/
    │   ├── splash_view.dart
    │   ├── login_view.dart
    │   └── register_view.dart
    ├── lecturer/
    │   ├── lecturer_home_view.dart   ← Dashboard with live stats
    │   ├── session_list_view.dart    ← Sessions with countdown bar
    │   ├── session_detail_view.dart  ← Live QR code + attendee list
    │   ├── create_session_view.dart  ← New session form
    │   ├── courses_view.dart         ← Course management
    │   └── profile_view.dart
    ├── student/
    │   ├── student_home_view.dart    ← Dashboard with sync banner
    │   ├── scan_view.dart            ← Camera QR scanner
    │   ├── attendance_history_view.dart
    │   └── student_profile_view.dart
    └── shared/widgets/
        ├── app_button.dart           ← Gradient + outlined buttons
        ├── app_text_field.dart       ← Reusable input field
        ├── status_badge.dart         ← Colour-coded status chips
        ├── connectivity_banner.dart  ← Offline mode banner
        └── stats_card.dart           ← Dashboard statistic card
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.22.0 |
| Dart SDK | ≥ 3.3.0 |
| Android SDK | API 26+ |
| Java | 17 |

---

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure the backend URL

Edit `lib/core/constants/app_constants.dart`:

```dart
// For Android emulator talking to localhost Django server:
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

// For a real device on the same WiFi:
static const String baseUrl = 'http://192.168.X.X:8000/api/v1';

// For production:
static const String baseUrl = 'https://yourdomain.com/api/v1';
```

### 3. Start the Django backend

```bash
cd ../smart_attendance          # the Django project
python manage.py runserver 0.0.0.0:8000
```

### 4. Run the Flutter app

```bash
flutter run                     # connects to attached device/emulator
flutter run -d emulator-5554    # specific emulator
```

### 5. Run unit tests

```bash
flutter test
```

### 6. Build for presentation/demo

```bash
flutter build apk --debug
```

This produces a debug APK suitable for live demonstration and validation during a thesis defense.

---

## Key Features

### Security (matches research proposal Section 3.5)

| Feature | Implementation |
|---|---|
| HMAC-SHA256 QR signing | `lib/core/utils/qr_utils.dart` |
| Device UUID binding | `SecureStorageService` + `AuthService.getDeviceUuid()` |
| Local duplicate prevention | SQLite `UNIQUE(student_id, session_id, device_uuid)` |
| QR expiry enforcement | 15-min window with 5-min clock-skew tolerance |
| Server re-validation | Django backend re-validates every sync record |

### Offline-First (Section 3.3 & 3.6)

- All 4 QR validations run **without internet** (HMAC, expiry, device UUID, duplicate)
- `AttendanceRecord` stored locally with `pending_sync = 1`
- `ConnectivityService` monitors network state in real-time
- `AttendanceController.syncPending()` fires automatically on reconnection
- QR payload regenerated locally every 15 min using cached `session_secret`

### UI Highlights

- Material 3 design with custom `AppTheme`
- Animated splash, login card slide-in
- Live countdown timer on QR code with colour-coded urgency
- Pulsing QR animation (lecturer display)
- Scan result bottom sheet (success / duplicate / error)
- Offline mode banner across all screens
- Sync pending badge on bottom nav
- `StatsCard` grid dashboards for both roles

---

## QR Payload Format

```
<session_id>|<course_code>|<expiry_unix>|<hmac_sha256>

Example:
3f2a1b4c-...|CPE501|1743494100|a3f9b2c1...
```

The HMAC key (`session_secret`) is fetched from the server at session creation
and cached locally on the **Lecturer** device only. Students never receive it —
they verify by re-sending the raw payload to the server during online scans,
or the local client re-validates during offline scans using the cached secret.

---

## Screens

| Screen | Role | Description |
|---|---|---|
| Splash | Both | Animated boot screen; checks cached auth |
| Login | Both | JWT login with device binding |
| Register | Both | Student/Lecturer registration |
| Lecturer Dashboard | Lecturer | Stats: courses, sessions, students reached |
| Session List | Lecturer | All sessions with live countdown progress bar |
| Session Detail | Lecturer | Fullscreen QR + attendee list + close button |
| Create Session | Lecturer | Course picker + venue form |
| Courses | Lecturer | Course list + create course sheet |
| Student Dashboard | Student | Stats + sync banner + recent records |
| Scan | Student | Camera scanner with overlay + result sheet |
| History | Student | Attendance records with sync status |
| Profile | Both | User info, device binding, sync control, logout |

---

## Build for release

```bash
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk

flutter build appbundle --release
# AAB at: build/app/outputs/bundle/release/app-release.aab
```

---

*Civilsalt Attendance – Flutter v1.0 · UBa25EP188 · Attendance Crisis Solution · 2025*
