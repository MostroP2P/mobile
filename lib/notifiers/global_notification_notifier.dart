import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class NotificationState {
  final MostroMessage? message;
  final VoidCallback? cancel;
  final VoidCallback? ok;

  NotificationState({this.message, this.cancel, this.ok});
}

class GlobalNotificationNotifier extends StateNotifier<NotificationState> {
  GlobalNotificationNotifier() : super(NotificationState());

  void showDialog(
      MostroMessage message, VoidCallback cancel, VoidCallback ok) {}

  void showNotification(MostroMessage message, VoidCallback onTap) {
    state = NotificationState(message: message, ok: onTap);
  }

  void clearNotification() {
    state = NotificationState();
  }
}
