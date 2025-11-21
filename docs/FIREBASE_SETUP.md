# Firebase and FCM Setup Guide

This guide explains how to configure Firebase and Firebase Cloud Messaging (FCM) for the Mostro Mobile app.

## Table of Contents

- [Overview](#overview)
- [Security Note](#security-note)
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Android Configuration](#android-configuration)
- [iOS Configuration](#ios-configuration)
- [Firebase Cloud Functions](#firebase-cloud-functions)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview

The Mostro Mobile app uses Firebase Cloud Messaging (FCM) for silent push notifications. This allows the backend to wake up the app when new Mostro events are available, enabling real-time notifications without constant polling.

### Architecture

```
Cloud Functions → FCM Topic → All App Instances → Fetch from Nostr Relays → Show Notifications
```

**Privacy-preserving approach:**
- FCM sends **empty** silent push notifications (no event data)
- All app instances receive the same notification
- Each app fetches and decrypts events locally
- No user-to-token mapping required on the backend

## Security Note

### What credentials are PUBLIC (safe in git)

These files contain **public credentials** that are safe to commit:

- ✅ `android/app/google-services.json` - Android Firebase config
- ✅ `ios/Runner/GoogleService-Info.plist` - iOS Firebase config
- ✅ `lib/firebase_options.dart` - Generated Firebase options

**Why these are safe:**
- API keys are public identifiers (not secrets)
- They're embedded in distributed apps (decompilable)
- Security comes from Firebase Security Rules, not hidden keys
- See [Firebase API Keys Documentation](https://firebase.google.com/docs/projects/api-keys)

### What credentials are PRIVATE (never commit)

These must **NEVER** be committed to git:

- ❌ Service Account Keys (`*-firebase-adminsdk-*.json`) with `private_key`
- ❌ These are used by Cloud Functions (already secured by Firebase)
- ❌ Never expose these in client code

**Already protected in `.gitignore`:**
```gitignore
# Private keys (DO NOT COMMIT)
android/key.properties
android/app/upload-keystore.jks
*.jks
```

## Prerequisites

- Firebase account ([console.firebase.google.com](https://console.firebase.google.com))
- Flutter SDK installed
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## Initial Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name (e.g., "mostro-production")
4. Follow the setup wizard

### 2. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 3. Login to Firebase

```bash
firebase login
flutterfire configure
```

### 4. Configure Project

```bash
cd mobile
flutterfire configure --project=your-firebase-project-id
```

This will:
- Generate `lib/firebase_options.dart`
- Create `android/app/google-services.json`
- Create `ios/Runner/GoogleService-Info.plist` (if iOS configured)

## Android Configuration

### 1. Verify google-services.json

The file should exist at:
```
android/app/google-services.json
```

**DO NOT** add this to `.gitignore` - it contains only public credentials.

### 2. Verify Gradle Configuration

Check `android/app/build.gradle`:

```gradle
dependencies {
    // Firebase
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}

apply plugin: 'com.google.gms.google-services'
```

### 3. Build the App

```bash
flutter build apk
```

If you get errors about missing `google-services.json`, run:
```bash
git pull  # File should be in the repository
```

## iOS Configuration

### 1. Configure APNs

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Create an APNs Authentication Key:
   - Click on Keys → (+)
   - Enable "Apple Push Notifications service (APNs)"
   - Download the `.p8` key file
   - Note the Key ID

### 2. Upload APNs Key to Firebase

1. Go to Firebase Console → Project Settings
2. Select "Cloud Messaging" tab
3. Under "Apple app configuration"
4. Upload your `.p8` key file
5. Enter Team ID and Key ID

### 3. Add GoogleService-Info.plist

Download from Firebase Console and place at:
```
ios/Runner/GoogleService-Info.plist
```

**DO NOT** add to `.gitignore` - it contains only public credentials.

### 4. Configure Capabilities

In Xcode:
1. Open `ios/Runner.xcworkspace`
2. Select Runner target → Signing & Capabilities
3. Add "Push Notifications" capability
4. Add "Background Modes" capability
   - Enable "Background fetch"
   - Enable "Remote notifications"

## Firebase Cloud Functions

### 1. Navigate to Functions Directory

```bash
cd functions
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment

The Cloud Functions are already configured in `functions/src/index.ts`:

- **Nostr Relays**: Configured in code (line 30-32)
- **Mostro Pubkey**: Configured in code (line 36-37)
- **FCM Topic**: `mostro_notifications` (line 40)

### 4. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

This deploys:
- `keepAlive` - Scheduled function (runs every 5 minutes)
- `sendTestNotification` - HTTP endpoint for testing
- `getStatus` - HTTP endpoint for status checks

### 5. Verify Deployment

Check the Firebase Console → Functions to see deployed functions.

## Testing

### 1. Test Local Notifications

Run the app in debug mode:
```bash
flutter run
```

### 2. Test FCM Integration

#### Check FCM Token

The app logs the FCM token on startup:
```
[FCMService] FCM token obtained: eyJhbGciOiJSUzI1NiIsI...
```

#### Send Test Notification

Use the Cloud Functions HTTP endpoint:
```bash
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendTestNotification
```

#### Monitor Logs

```bash
# App logs
flutter logs

# Cloud Functions logs
firebase functions:log
```

### 3. Test Silent Push Flow

1. **Backend sends silent push** → All devices receive empty FCM message
2. **Background handler sets flag** → `fcm.pending_fetch = true`
3. **Foreground listener checks flag** → Fetches events from Nostr relays
4. **App shows notifications** → Based on decrypted events

## Troubleshooting

### Android Build Fails: "google-services.json is missing"

**Solution:**
```bash
git pull  # File should be in repository
# If still missing, run:
flutterfire configure
```

### FCM Token is null

**Common causes:**
- No internet connection
- Google Play Services not installed (Android)
- Notification permissions not granted

**Solution:**
```dart
// Check permissions
final permissionGranted = await FirebaseMessaging.instance.requestPermission();
```

### Silent Push Not Waking App

**Android:**
- Check battery optimization settings
- Disable "Battery Optimization" for the app

**iOS:**
- Verify APNs configuration
- Check that `content-available: 1` is in payload
- Ensure `apns-priority: 5` for background notifications

### Cloud Functions Not Deploying

**Check Firebase CLI version:**
```bash
npm install -g firebase-tools@latest
```

**Check Node version:**
```bash
node --version  # Should be 18 or higher
```

### Notifications Not Showing

**Check notification permissions:**
```dart
final settings = await FirebaseMessaging.instance.getNotificationSettings();
print('Permission: ${settings.authorizationStatus}');
```

**Android:**
- Verify notification channel is created
- Check Do Not Disturb settings

**iOS:**
- Check notification settings in Settings app
- Verify app is not in Low Power Mode

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev)
- [FCM Setup Guide](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- [APNs Setup Guide](https://firebase.google.com/docs/cloud-messaging/ios/certs)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)

## Support

For issues specific to this project:
- Open an issue on GitHub
- Check existing issues for solutions
- Review app logs: `flutter logs`
- Review Cloud Functions logs: `firebase functions:log`
