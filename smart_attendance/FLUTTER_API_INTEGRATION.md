# Smart Attendance API – Flutter Integration Guide

**Version:** 1.0.0  
**Base path:** `/api/v1/`  
**Auth:** JWT Bearer tokens (`Authorization: Bearer <access_token>`)

Use this document to wire your Flutter app to the backend. It lists every endpoint, request/response shapes, roles, and recent validation fixes so you avoid 500 errors.

---

## 1. Base URL configuration

| Environment | Base URL |
|-------------|----------|
| Android emulator | `https://qrscanner-5qk4.onrender.com` |
| iOS simulator | `https://qrscanner-5qk4.onrender.com` |
| Physical device (same Wi‑Fi) | `http://<YOUR_PC_LAN_IP>:8000` |

**Full API prefix:** `{BASE_URL}/api/v1/`

### Flutter example (`ApiConfig`)

```dart
class ApiConfig {
  // Change per environment
  static const String baseUrl = 'https://qrscanner-5qk4.onrendercom';
  static const String apiV1 = '$baseUrl/api/v1';
  static const String authBase = '$apiV1/auth';

  static Map<String, String> jsonHeaders({String? accessToken}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };
}
```

### Required packages

```yaml
dependencies:
  http: ^1.2.0          # or dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  device_info_plus: ^10.0.0   # for device_uuid
```

---

## 2. Authentication flow (Flutter)

```
Register (optional) → Login (+ device_uuid) → Store access + refresh
       ↓
All protected calls: Header Authorization: Bearer <access>
       ↓
On 401: POST /auth/token/refresh/ → retry with new access
       ↓
Logout: POST /auth/logout/ with refresh body
```

| Token | Lifetime |
|-------|----------|
| Access | 1 hour |
| Refresh | 7 days (rotates on refresh; old refresh is blacklisted) |

---

## 3. Common headers & errors

### Headers (protected endpoints)

```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <access_token>
```

### HTTP status codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 205 | Logout successful |
| 400 | Validation error (fix request body) |
| 401 | Missing/invalid/expired token |
| 403 | Wrong role or permission |
| 404 | Resource not found |
| 500 | Server error (should not happen for normal bad input after fixes) |

### Error response shape (400)

Field errors (registration, enrolment, etc.):

```json
{
  "email": ["Enter a valid email address."],
  "password_confirm": ["This field is required."]
}
```

Or enrolment:

```json
{
  "student_ids": ["'not-a-uuid' is not a valid UUID."]
}
```

Generic detail:

```json
{
  "detail": "Session not found."
}
```

**Flutter tip:** Never assume 500 for bad input; parse `response.body` as JSON and show field errors to the user.

---

## 4. Recent endpoint modifications (important for Flutter)

These changes were made so invalid client data returns **400**, not **500**.

| Endpoint | Change | What Flutter must send |
|----------|--------|-------------------------|
| `POST /auth/register/` | Stricter validation | Valid email, `password` + `password_confirm` (required), min 8 chars |
| `POST /auth/logout/` | `refresh` is **required** | Body: `{ "refresh": "<refresh_token>" }` |
| `POST /courses/{id}/enrol/` | UUID validation | `student_ids` must be a **list of valid student UUID strings** |
| All endpoints | Safer error handling | Invalid UUIDs / bad payloads → 400 with clear `student_ids` or field keys |

### Enrolment – correct Flutter payload

```dart
// student_ids MUST be List<String> of valid UUIDs from GET /auth/users/?role=student
await http.post(
  Uri.parse('${ApiConfig.apiV1}/courses/$courseId/enrol/'),
  headers: ApiConfig.jsonHeaders(accessToken: access),
  body: jsonEncode({
    'student_ids': [studentUuid1, studentUuid2],  // NOT registration numbers
  }),
);
```

**Wrong (caused 500 before, now 400):**

```json
{ "student_ids": ["not-a-uuid"] }
{ "student_ids": ["UBa25EP001"] }
```

---

## 5. Auth endpoints (`/api/v1/auth/`)

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/register/` | No | Public | Register user |
| POST | `/login/` | No | Public | Login + optional device bind |
| POST | `/token/refresh/` | No | Public | Refresh access token |
| POST | `/logout/` | Yes | Any | Blacklist refresh token |
| GET | `/profile/` | Yes | Any | Get profile |
| PATCH | `/profile/` | Yes | Any | Update name / registration_number |
| GET | `/users/` | Yes | Lecturer, Admin | List users |
| POST | `/admin/rebind-device/` | Yes | Admin | Rebind student device |
| GET | `/admin/device-logs/` | Yes | Admin | Device binding audit log |

---

### 5.1 POST `/auth/register/`

**Request:**

```json
{
  "email": "student@nahpi.cm",
  "first_name": "Ronald",
  "last_name": "Buhnyuy",
  "registration_number": "UBa25EP188",
  "role": "student",
  "password": "SecurePass123",
  "password_confirm": "SecurePass123"
}
```

| Field | Type | Rules |
|-------|------|-------|
| `email` | string | Valid email; stored lowercase |
| `role` | string | `student` \| `lecturer` \| `admin` |
| `password` | string | Min 8 characters |
| `password_confirm` | string | Required; must match `password` |
| `registration_number` | string | Unique (students) |

**Response 201:**

```json
{
  "message": "Registration successful.",
  "user": {
    "id": "uuid",
    "email": "student@nahpi.cm",
    "first_name": "Ronald",
    "last_name": "Buhnyuy",
    "full_name": "Ronald Buhnyuy",
    "registration_number": "UBa25EP188",
    "role": "student",
    "device_uuid": null,
    "device_bound_at": null,
    "date_joined": "...",
    "updated_at": "..."
  }
}
```

**Response 400 examples:**

```json
{ "email": ["Enter a valid email address."] }
{ "password_confirm": ["This field is required."] }
{ "password_confirm": ["Passwords do not match."] }
```

---

### 5.2 POST `/auth/login/`

**Request:**

```json
{
  "email": "student@nahpi.cm",
  "password": "SecurePass123",
  "device_uuid": "optional-android-id-from-device_info_plus"
}
```

**Response 200:**

```json
{
  "access": "eyJ...",
  "refresh": "eyJ...",
  "user": {
    "id": "uuid",
    "email": "student@nahpi.cm",
    "full_name": "Ronald Buhnyuy",
    "role": "student",
    "registration_number": "UBa25EP188",
    "device_uuid": "android-id-...",
    "device_bound_at": "2026-05-19T10:00:00+01:00"
  }
}
```

**Device binding rules:**

- First login with `device_uuid` → binds device to account.
- Later login with **different** `device_uuid` → **400**:

```json
{
  "device_uuid": [
    "This account is already bound to a different device. Contact your administrator to rebind."
  ]
}
```

**Flutter:** Always send the same `device_uuid` from `device_info_plus` on login and on every scan/sync.

---

### 5.3 POST `/auth/token/refresh/`

**Request:**

```json
{ "refresh": "<refresh_token>" }
```

**Response 200:**

```json
{
  "access": "<new_access_token>",
  "refresh": "<new_refresh_token>"
}
```

Store **both** new tokens (rotation blacklists the old refresh).

---

### 5.4 POST `/auth/logout/`

**Auth required.** **`refresh` is required** (updated behaviour).

**Request:**

```json
{ "refresh": "<refresh_token>" }
```

**Response 205:**

```json
{ "detail": "Logout successful." }
```

**Response 400 (missing refresh):**

```json
{ "refresh": ["This field is required."] }
```

---

### 5.5 GET / PATCH `/auth/profile/`

**GET 200:** Same user object as registration (without password fields).

**PATCH body (partial):**

```json
{
  "first_name": "Updated",
  "last_name": "Name",
  "registration_number": "UBa25EP199"
}
```

Read-only: `id`, `email`, `device_uuid`, `device_bound_at`, `date_joined`, `updated_at`.

---

### 5.6 GET `/auth/users/`

**Query:** `?role=student` or `?role=lecturer`

**Response 200:** Paginated list (page size 20):

```json
{
  "count": 50,
  "next": "http://.../users/?page=2",
  "previous": null,
  "results": [ { "id": "uuid", "email": "...", "role": "student", ... } ]
}
```

Use `results[].id` as `student_ids` when enrolling students.

---

### 5.7 POST `/auth/admin/rebind-device/` (Admin only)

**Request:**

```json
{
  "user_id": "student-uuid",
  "new_device_uuid": "new-device-id",
  "reason": "Lost phone"
}
```

**Response 200:**

```json
{
  "message": "Device rebound for Student Name.",
  "user_id": "uuid",
  "new_device_uuid": "new-device-id"
}
```

---

### 5.8 GET `/auth/admin/device-logs/` (Admin only)

**Response 200:** Array of log entries:

```json
[
  {
    "id": 1,
    "user": "Ronald Buhnyuy",
    "user_id": "uuid",
    "old_device_uuid": null,
    "new_device_uuid": "android-id",
    "ip_address": "127.0.0.1",
    "created_at": "2026-05-19T10:00:00+01:00"
  }
]
```

---

## 6. Health (public)

### GET `/api/v1/health/`

No auth.

**Response 200:**

```json
{
  "status": "ok",
  "database": "connected",
  "system": "Smart Attendance System v1.0"
}
```

Use on app startup to verify server reachability.

---

## 7. Course endpoints (`/api/v1/`)

| Method | Path | Auth | Role |
|--------|------|------|------|
| GET | `/courses/` | Yes | Any (filtered by role) |
| POST | `/courses/` | Yes | Lecturer, Admin |
| GET | `/courses/{uuid}/` | Yes | Any |
| PUT/PATCH | `/courses/{uuid}/` | Yes | Lecturer, Admin |
| DELETE | `/courses/{uuid}/` | Yes | Lecturer, Admin |
| POST | `/courses/{uuid}/enrol/` | Yes | Lecturer, Admin |

### POST `/courses/` – create

```json
{
  "code": "CPE501",
  "title": "Advanced Computer Networks",
  "lecturer": "lecturer-user-uuid"
}
```

### POST `/courses/{uuid}/enrol/` – enrol students (updated)

```json
{
  "student_ids": [
    "11111111-1111-1111-1111-111111111111",
    "22222222-2222-2222-2222-222222222222"
  ]
}
```

| Response | Body |
|----------|------|
| 200 | `{ "message": "Enrolment updated. 2 student(s) enrolled." }` |
| 400 | `{ "student_ids": ["'bad-id' is not a valid UUID."] }` |
| 400 | `{ "student_ids": ["Unknown or non-student user IDs: [...]"] }` |
| 404 | `{ "detail": "Course not found." }` |

---

## 8. Session endpoints (`/api/v1/`)

| Method | Path | Auth | Role |
|--------|------|------|------|
| GET | `/sessions/` | Yes | Any (filtered) |
| POST | `/sessions/` | Yes | **Lecturer only** |
| GET | `/sessions/{uuid}/` | Yes | Any |
| POST | `/sessions/{uuid}/close/` | Yes | Lecturer (owner) |
| GET | `/sessions/{uuid}/qr/` | Yes | Lecturer (owner) |

### POST `/sessions/` – open session (lecturer)

**Request:**

```json
{
  "course": "course-uuid",
  "venue": "Room 201",
  "notes": "Week 5"
}
```

**Response 201:**

```json
{
  "id": "session-uuid",
  "course": "course-uuid",
  "course_code": "CPE501",
  "status": "open",
  "started_at": "2026-05-19T10:00:00+01:00",
  "expires_at": "2026-05-19T10:15:00+01:00",
  "expiry_unix": 1747651200,
  "venue": "Room 201",
  "notes": "Week 5",
  "session_secret": "128-char-hex-secret-lecturer-only",
  "qr_payload": "session-uuid|CPE501|1747651200|hmac-sha256-hex"
}
```

**Flutter (lecturer app):**

- Store `session_secret` securely (lecturer device only).
- Display `qr_payload` as QR code (e.g. `qr_flutter` package).
- Call `GET /sessions/{id}/qr/` to refresh before expiry.

### POST `/sessions/{uuid}/close/`

No body. **Response 200:**

```json
{
  "message": "Session closed.",
  "session_id": "uuid",
  "closed_at": "2026-05-19T10:20:00+01:00"
}
```

### GET `/sessions/{uuid}/qr/` – refresh QR

**Response 200:** Same shape as session create (new `qr_payload`, extended `expires_at`).

---

## 9. Attendance endpoints (`/api/v1/`)

| Method | Path | Auth | Role |
|--------|------|------|------|
| POST | `/attendance/scan/` | Yes | **Student only** |
| GET | `/attendance/records/` | Yes | Any (filtered) |

### POST `/attendance/scan/` – online scan (student)

**Request:**

```json
{
  "session_id": "session-uuid",
  "qr_payload": "session-uuid|CPE501|1747651200|hmachex",
  "device_uuid": "same-as-login-device-uuid",
  "scanned_at": "2026-05-19T10:05:00.000Z"
}
```

Use ISO 8601 for `scanned_at` (`DateTime.now().toUtc().toIso8601String()`).

**Response 201:**

```json
{
  "message": "Attendance recorded.",
  "record": {
    "id": "uuid",
    "student": "student-uuid",
    "student_name": "Ronald Buhnyuy",
    "session": "session-uuid",
    "session_info": { "id": "...", "course": "CPE501" },
    "device_uuid": "...",
    "scan_source": "online",
    "scanned_at": "...",
    "synced_at": "...",
    "idempotency_key": "...",
    "pending_sync": false
  }
}
```

**Response 400 examples:**

```json
{ "device_uuid": ["Device UUID does not match the registered device for this account."] }
{ "qr_payload": ["QR verification failed: invalid_hmac"] }
{ "qr_payload": ["QR verification failed: expired"] }
{ "non_field_errors": ["Attendance already recorded for this session."] }
```

### GET `/attendance/records/`

**Query (optional):** `?course_id=<uuid>&session_id=<uuid>`

**Response 200:** Paginated `AttendanceRecord` list.

---

## 10. Sync endpoints (`/api/v1/`) – offline mode

| Method | Path | Auth | Role |
|--------|------|------|------|
| POST | `/sync/` | Yes | **Student only** |
| GET | `/sync/history/` | Yes | Student (own batches) |

### POST `/sync/` – batch upload

**Request:**

```json
{
  "device_uuid": "student-device-uuid",
  "records": [
    {
      "session_id": "session-uuid",
      "device_uuid": "student-device-uuid",
      "scanned_at": "2026-05-19T10:05:00.000Z",
      "idempotency_key": "device-uuid|session-uuid|1747650300000",
      "hmac_signature": "hmac-from-qr-payload",
      "qr_payload": "session-uuid|CPE501|1747651200|hmachex"
    }
  ]
}
```

**Idempotency key format (must be unique per scan):**

```
{device_uuid}|{session_id}|{scanned_at_unix_ms}
```

**Response 200:**

```json
{
  "batch_id": "uuid",
  "total_submitted": 5,
  "accepted": 4,
  "rejected": 0,
  "duplicates": 1,
  "conflicts_flagged": 0,
  "status": "complete"
}
```

`status`: `complete` \| `partial` \| `pending` \| `failed`

**Response 403:** Device UUID in batch does not match registered device.

### GET `/sync/history/`

**Response 200:** Paginated list of sync batches.

---

## 11. Report endpoints (`/api/v1/`)

| Method | Path | Auth | Role |
|--------|------|------|------|
| GET | `/reports/sessions/{uuid}/` | Yes | Lecturer, Admin |
| GET | `/reports/courses/{uuid}/` | Yes | Lecturer, Admin |

### GET `/reports/courses/{course_id}/`

**Response 200:**

```json
{
  "course_id": "uuid",
  "course_code": "CPE501",
  "course_title": "Advanced Networks",
  "total_sessions": 10,
  "student_summary": [
    {
      "student_id": "uuid",
      "student_name": "Ronald Buhnyuy",
      "registration_number": "UBa25EP188",
      "sessions_attended": 8,
      "total_sessions": 10,
      "attendance_rate": 80.0
    }
  ]
}
```

---

## 12. Log endpoints (`/api/v1/`)

| Method | Path | Auth | Role |
|--------|------|------|------|
| GET | `/logs/conflicts/` | Yes | Lecturer, Admin |
| POST | `/logs/conflicts/{id}/resolve/` | Yes | Lecturer, Admin |
| GET | `/logs/integrity/` | Yes | **Admin only** |

### POST `/logs/conflicts/{id}/resolve/`

```json
{ "resolution_note": "Student verified in person." }
```

**Response 200:** `{ "message": "Conflict resolved." }`

---

## 13. QR payload format (student & lecturer apps)

```
<session_id>|<course_code>|<expiry_unix>|<hmac_sha256_hex>
```

Example:

```
3f2a1b4c-8e2a-4b1c-9d3e-1a2b3c4d5e6f|CPE501|1747651200|a3f9b2c1d4e5f6...
```

- Students receive only the **full `qr_payload` string** (from QR scan).
- Lecturers receive `session_secret` at session creation (for local re-generation if needed).
- Default QR validity: **900 seconds** (15 minutes).

---

## 14. Role-based endpoint matrix (quick reference)

| Endpoint | Student | Lecturer | Admin |
|----------|:-------:|:--------:|:-----:|
| register, login, refresh, health | ✓ | ✓ | ✓ |
| profile, logout | ✓ | ✓ | ✓ |
| users list | ✗ | ✓ | ✓ |
| rebind-device, device-logs | ✗ | ✗ | ✓ |
| courses list | enrolled | own | all |
| create course / session | ✗ | ✓ | ✓ |
| attendance scan, sync | ✓ | ✗ | ✗ |
| reports, conflicts | ✗ | ✓ | ✓ |
| integrity logs | ✗ | ✗ | ✓ |

---

## 15. Flutter service skeleton

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String base = ApiConfig.authBase;
  String? accessToken;
  String? refreshToken;

  Future<void> login(String email, String password, String deviceUuid) async {
    final res = await http.post(
      Uri.parse('$base/login/'),
      headers: ApiConfig.jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_uuid': deviceUuid,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)); // parse field errors
    }
    final data = jsonDecode(res.body);
    accessToken = data['access'];
    refreshToken = data['refresh'];
    // persist with flutter_secure_storage
  }

  Future<void> refreshAccess() async {
    final res = await http.post(
      Uri.parse('$base/token/refresh/'),
      headers: ApiConfig.jsonHeaders(),
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      accessToken = data['access'];
      refreshToken = data['refresh'];
    }
  }

  Future<http.Response> authenticatedGet(String path) async {
    var res = await http.get(
      Uri.parse('${ApiConfig.apiV1}$path'),
      headers: ApiConfig.jsonHeaders(accessToken: accessToken),
    );
    if (res.statusCode == 401) {
      await refreshAccess();
      res = await http.get(
        Uri.parse('${ApiConfig.apiV1}$path'),
        headers: ApiConfig.jsonHeaders(accessToken: accessToken),
      );
    }
    return res;
  }
}
```

---

## 16. Interactive API docs (browser)

| Tool | URL |
|------|-----|
| Swagger UI | `{BASE_URL}/api/docs/` |
| ReDoc | `{BASE_URL}/api/redoc/` |
| OpenAPI JSON | `{BASE_URL}/api/schema/` |

---

## 17. Checklist before connecting Flutter

- [ ] Server running: `python manage.py runserver 0.0.0.0:8000`
- [ ] Correct base URL for emulator vs real device
- [ ] Store `access` + `refresh` after login
- [ ] Send `device_uuid` on login, scan, and sync
- [ ] Use **student UUIDs** (not matric numbers) in `student_ids`
- [ ] Include `password_confirm` on registration
- [ ] Send `refresh` on logout
- [ ] Handle 400 responses by showing JSON field errors
- [ ] On 401, call token refresh then retry

---

*Smart Attendance System – Flutter Integration Guide v1.0*  
*NAHPI, University of Bamenda · Buhnyuy Ronald Yika (UBa25EP188)*
