import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationMessage {
  final String message;
  final VoidCallback onTap;

  NotificationMessage({required this.message, required this.onTap});
}

class GlobalNotificationNotifier extends StateNotifier<NotificationMessage?> {
  GlobalNotificationNotifier() : super(null);

  void showNotification(String message, VoidCallback onTap) {
    state = NotificationMessage(message: message, onTap: onTap);
  }

  void clearNotification() {
    state = null;
  }
}
