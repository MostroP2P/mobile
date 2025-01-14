import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class NotificationState {
  final actions.Action? action;
  final Map<String, dynamic> placeholders;
  final WidgetBuilder? widgetBuilder;
  final bool informational;
  final bool actionRequired;

  NotificationState(
      {this.action,
      this.placeholders = const {},
      this.widgetBuilder,
      this.informational = false,
      this.actionRequired = false});
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState());

  void showInformation(actions.Action action,
      {Map<String, dynamic> values = const {}}) {
    state = NotificationState(
        action: action, placeholders: values, informational: true);
  }

  void showActionable(actions.Action action,
      {Map<String, dynamic> values = const {}}) {
    state = NotificationState(
        action: action, placeholders: values, actionRequired: true);
  }

  void clearNotification() {
    state = NotificationState();
  }
}
