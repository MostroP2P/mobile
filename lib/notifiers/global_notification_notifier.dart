import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class NotificationState {
  final MostroMessage? message;
  final WidgetBuilder? widgetBuilder;

  NotificationState({this.message, this.widgetBuilder});
}

class GlobalNotificationNotifier extends StateNotifier<NotificationState> {
  GlobalNotificationNotifier() : super(NotificationState());

  void showDialog(
      MostroMessage message, VoidCallback cancel, VoidCallback ok) {}

  void showNotification(MostroMessage message, WidgetBuilder builder) {
    state = NotificationState(message: message, widgetBuilder: builder);
  }

  void showScreen(WidgetBuilder builder) {
    state = NotificationState(widgetBuilder: builder);
  }

  void clearNotification() {
    state = NotificationState();
  }
}
