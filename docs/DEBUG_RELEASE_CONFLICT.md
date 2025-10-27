# Debug/Release APK Install Conflict

## The Problem

When you run the app with `flutter run` (debug mode) and then try to install a release APK, Android shows a **"App not installed" conflict error**.

**Why this happens:**
- **Debug builds** (`flutter run`) → Signed with Flutter's debug keystore
- **Release builds** → Signed with your production keystore (or debug if not configured)
- Android won't install an APK signed with a different certificate over an existing app

## Quick Solution

Uninstall the existing app first:

```bash
# Uninstall the app
adb uninstall network.mostro.app

# Then install the release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or from your device: **Settings → Apps → Mostro → Uninstall**, then install the new APK.

## Permanent Solution

Configure your local development to use the same keystore for both debug and release builds. This way you can switch between `flutter run` and release APKs without conflicts.

**See the complete setup guide:** [`docs/GITHUB_SECRETS_SETUP.md`](docs/GITHUB_SECRETS_SETUP.md)

The guide covers:
- Creating a keystore from scratch
- Configuring `key.properties` for local builds
- Setting up GitHub Actions for CI/CD
- Troubleshooting signing issues

## Additional Notes

### Verifying which keystore is being used

```bash
flutter build apk --release 2>&1 | grep -i "signing\|keystore"
```

**Good**: No warnings  
**Bad**: "Release build using debug signing - keystore not available"

### Want to keep using debug signing?

If you prefer to keep debug and release builds separate (and don't mind uninstalling between switches), simply don't create a `key.properties` file. The build will automatically use debug signing for both.

## References

- [Flutter - Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Android - Sign your app](https://developer.android.com/studio/publish/app-signing)
