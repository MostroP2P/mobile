import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Requests notification permission at runtime (Android 13+/API 33+).
Future<void> requestNotificationPermissionIfNeeded() async {
  if (Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST')) {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.notification.request();
    }
  }
}
