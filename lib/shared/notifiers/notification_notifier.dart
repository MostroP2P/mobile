import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class NotificationState {
  final MostroMessage? message;
  final WidgetBuilder? widgetBuilder;
  final bool showSnackbar;

  NotificationState(
      {this.message, this.widgetBuilder, this.showSnackbar = false});
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState());

  void clearNotification() {
    state = NotificationState();
  }
}
