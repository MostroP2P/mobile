import 'package:permission_handler/permission_handler.dart';

/// Requests notification permission at runtime (Android 13+/API 33+).
Future<void> requestNotificationPermissionIfNeeded() async {
  final status = await Permission.notification.status;
  if (status.isDenied || status.isRestricted) {
    await Permission.notification.request();
  }
}
