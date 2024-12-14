import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class NotificationState {
  final MostroMessage? message;
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

  void clearNotification() {
    state = NotificationState();
  }
}
