# Firebase on Linux

## Important Note

Firebase is **not supported on Linux**. The app will compile and run on Linux, but Firebase features (push notifications) will not be available.

## Implementation

When initializing Firebase in your code, always check the platform first:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> initializeFirebase() async {
  // Skip Firebase initialization on Linux
  if (!kIsWeb && Platform.isLinux) {
    print('Firebase not supported on Linux - skipping initialization');
    return;
  }
  
  // Initialize Firebase for supported platforms
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

## Why This Approach?

- `pubspec.yaml` doesn't support conditional dependencies per platform
- Flutter will include Firebase packages but they won't be used on Linux
- The app compiles successfully on all platforms
- Push notifications gracefully degrade on Linux

## Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ❌ Linux (compiles but Firebase features disabled)
