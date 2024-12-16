import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationState {
  final String? message;
  final WidgetBuilder? widgetBuilder;
  final bool informational;
  final bool actionRequired;

  NotificationState(
      {this.message,
      this.widgetBuilder,
      this.informational = false,
      this.actionRequired = false});
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState());

  void showInformation(String message) {
    state = NotificationState(message: message, informational: true);
  }

  void clearNotification() {
    state = NotificationState();
  }
}
