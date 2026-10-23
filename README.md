# Media Drive Backup - Flutter Application

A Flutter-only mobile application for scanning, analyzing, and automatically backing up device photos and videos directly to Google Drive.

Designed for direct mobile-to-cloud synchronization with **zero custom backend, zero intermediate server proxies, and zero third-party telemetry**.

---

## Architecture Overview

```
Mobile Device (Android / iOS)
 ├── Native Media Library (photo_manager)
 ├── Local ACID Manifest (sqflite / SQLite)
 ├── Local File Hash Engine (Streamed SHA-256)
 ├── Background & Battery Constraints Monitor (battery_plus, connectivity_plus)
 └── Direct Google Drive API (googleapis, google_sign_in)
         │
         ▼ (TLS 1.3 Direct HTTP)
    Google Drive API (drive.file scope)
         └── PhoneBackup/
               ├── Photos/YYYY/MM/
               ├── Videos/YYYY/MM/
               └── Metadata/
```

### Key Capabilities
- **Google OAuth 2.0**: Connect, disconnect, and re-authenticate using official Google Identity. Narrowest suitable scope: `https://www.googleapis.com/auth/drive.file`.
- **Media Scanner**: Discovers camera photos, screenshots, downloads, and videos incrementally. Fast metadata extraction without loading full-resolution images into RAM.
- **Media Analysis**:
  - Classifies MIME types and media types.
  - Groups media by creation timeline (Year / Month).
  - Flags large files (> 50 MB).
  - Detects duplicate files using content signatures and streamed SHA-256 hashing.
- **Direct Drive Uploads**:
  - Automatically creates and caches hierarchical folder structures (`PhoneBackup/Photos/<YYYY>/<MM>` and `PhoneBackup/Videos/<YYYY>/<MM>`).
  - Streamed chunk-based uploads with byte-level progress reporting.
  - Duplicate upload prevention.
  - Exponential backoff retry for transient network and rate-limit errors.
- **Local Manifest & Crash Recovery**:
  - SQLite database persists the full lifecycle of every media item: `DISCOVERED`, `ANALYSING`, `READY_TO_UPLOAD`, `UPLOADING`, `UPLOADED`, `RETRY_PENDING`, `FAILED`, `SKIPPED`.
  - Resets interrupted `UPLOADING` transfers on restart to resume cleanly.
- **Battery & Network Governance**:
  - Configurable Wi-Fi only mode vs Mobile data allowance.
  - Charging-only backup option.
  - Battery safety threshold (pauses backup if battery drops below user-defined percentage).
  - Maximum video size threshold.
  - Local-Only Testing Mode: enables scanning, hashing, and queue management without transmitting bytes to Drive.

---

## Google Cloud Console Setup

To test with your own Google account and Google Drive storage:

### 1. Create Google Cloud Project
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (e.g., `phone-media-backup`).

### 2. Enable the Google Drive API
1. Navigate to **APIs & Services > Library**.
2. Search for **Google Drive API** and click **Enable**.

### 3. Configure OAuth Consent Screen
1. Go to **APIs & Services > OAuth consent screen**.
2. Select **External** (for testing with your personal Google account).
3. Fill in App Name (`Media Drive Backup`) and your developer email.
4. Under **Scopes**, add:
   - `https://www.googleapis.com/auth/drive.file` (Create and manage files/folders created by this app)
   - `email`
   - `profile`
5. Under **Test Users**, add your personal Google account email address.

### 4. Create OAuth 2.0 Client IDs

#### For Android:
1. Go to **APIs & Services > Credentials > Create Credentials > OAuth client ID**.
2. Select Application type: **Android**.
3. Package name: `com.mediabackup.scanner.scanner` (configured in `android/app/build.gradle.kts`).
4. SHA-1 certificate fingerprint:
   - Run in terminal:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   - Copy the `SHA1` fingerprint and paste it into Google Cloud Console.

#### For iOS:
1. Go to **APIs & Services > Credentials > Create Credentials > OAuth client ID**.
2. Select Application type: **iOS**.
3. Bundle ID: `com.mediabackup.scanner.scanner` (configured in Xcode / `ios/Runner.xcodeproj`).
4. Copy the **Reversed Client ID** (e.g. `com.googleusercontent.apps.123456789-abcdef`).
5. Open `ios/Runner/Info.plist` and update the `CFBundleURLSchemes` array:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
       <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
   </array>
   ```

*(Optional)* You can also enter a custom OAuth 2.0 Client ID directly inside the app under **Google Drive Account > Developer OAuth Client Configuration**.

---

## Platform Permissions Configured

### Android (`android/app/src/main/AndroidManifest.xml`)
- `INTERNET` & `ACCESS_NETWORK_STATE`: For Google Drive API requests and Wi-Fi detection.
- `READ_MEDIA_IMAGES` & `READ_MEDIA_VIDEO`: Granular media permissions for Android 13+ (API 33+).
- `READ_MEDIA_VISUAL_USER_SELECTED`: Handles partial / selected-media access on Android 14+ (API 34+).
- `READ_EXTERNAL_STORAGE` (maxSdkVersion 32) & `WRITE_EXTERNAL_STORAGE` (maxSdkVersion 29): Android 12 and below.

### iOS (`ios/Runner/Info.plist`)
- `NSPhotoLibraryUsageDescription`: User-facing description explaining photo library scanning.
- `NSPhotoLibraryAddUsageDescription`: Permission for managing backup records.
- `CFBundleURLTypes`: Custom URL scheme for Google OAuth redirection.

---

## How to Run Locally

### 1. Requirements
- Flutter SDK 3.47+ (`flutter --version`)
- Dart 3.13+
- Android Studio / Android SDK (for Android device/emulator) or Xcode (for iOS device/simulator)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Verify Code Quality & Tests
```bash
flutter analyze
flutter test
```

### 4. Run the Application
Connect an Android or iOS test device and execute:
```bash
flutter run
```

---

## Testing Workflow & Upload Scenarios

1. **Permissions Verification**:
   - On first launch, open **Permissions & Privacy** from the side drawer.
   - Tap **Grant Media Permission**.
   - If partial access is selected (Android 14 / iOS), verify that the amber banner displays and explains that only selected media is indexed.
2. **Library Scan**:
   - Tap **Incremental Scan** or **Full Rescan** on the Dashboard or Scanner screen.
   - Observe real-time pagination progress and discovery metrics (Photos, Videos, Total Size).
3. **Google Authentication**:
   - Go to **Google Drive Account**.
   - Tap **Connect Google Drive Account** and sign in with your test Google account.
   - Verify that your email address and display name appear on the screen.
4. **Offline / Local Testing Mode**:
   - Go to **Settings > Testing & Development Mode** and toggle **Local-Only Mode**.
   - Run a backup; it will calculate SHA-256 hashes, group files, and test queue transitions without sending bytes to Drive.
5. **Real Google Drive Upload**:
   - Disable **Local-Only Mode**.
   - Tap **Start Backup**.
   - Watch live byte-level progress in the Queue or Dashboard.
   - Once completed, open Google Drive on the web to verify the folder hierarchy:
     `PhoneBackup/Photos/<YYYY>/<MM>/` and `PhoneBackup/Videos/<YYYY>/<MM>/`.
6. **Duplicate Upload Prevention**:
   - Trigger a rescan and start backup again.
   - Notice that previously uploaded files are detected via local manifest IDs and Drive queries; redundant byte uploads are skipped.
7. **Crash Recovery & Interrupted Transfers**:
   - Force-close the app while an upload is active.
   - Reopen the app: the SQLite manifest automatically recovers the interrupted task from `UPLOADING` to `RETRY_PENDING`.
8. **Network & Battery Constraints**:
   - Toggle **Back up over Wi-Fi only** on or off.
   - Disconnect Wi-Fi and observe that uploads pause automatically.
   - Reconnect Wi-Fi and tap Resume; transfers continue seamlessly.

---

## Known Platform Background Limitations

- **Android Doze & App Standby**: Android may delay background transfers when the device is idle or in battery saver mode. Tasks continue when the device is unlocked, connected to charger, or woken by system scheduler.
- **iOS Background Scheduling**: iOS decides when background transfers run based on system battery level, app usage habits, and thermal status.
- **Force-Stop**: Neither Android nor iOS allows an app to execute background work when the user has explicitly force-stopped the application from device task manager. Background sync resumes next time the user opens the application.
- **Original Media Safety**: This application NEVER deletes or modifies original media on the phone. All backup operations are strictly non-destructive read operations.
