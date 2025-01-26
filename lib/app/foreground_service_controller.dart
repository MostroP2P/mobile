import 'package:flutter/services.dart';

class ForegroundServiceController {
  static const _channel = MethodChannel('com.example.myapp/foreground_service');

  static Future<void> startService() async {
    try {
      await _channel.invokeMethod('startService');
    } on PlatformException catch (e) {
      print("Failed to start service: ${e.message}");
    }
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopService');
    } on PlatformException catch (e) {
      print("Failed to stop service: ${e.message}");
    }
  }
}
