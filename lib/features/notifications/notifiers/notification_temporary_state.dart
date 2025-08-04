import 'package:mostro_mobile/data/enums.dart';

class NotificationTemporaryState {
  final Action? action;
  final Map<String, dynamic> values;
  final bool show;
  final String? customMessage;

  const NotificationTemporaryState({
    this.action,
    this.values = const {},
    this.show = false,
    this.customMessage,
  });

  NotificationTemporaryState copyWith({
    Action? action,
    Map<String, dynamic>? values,
    bool? show,
    String? customMessage,
  }) {
    return NotificationTemporaryState(
      action: action ?? this.action,
      values: values ?? this.values,
      show: show ?? this.show,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTemporaryState &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          values == other.values &&
          show == other.show &&
          customMessage == other.customMessage;

  @override
  int get hashCode => Object.hash(action, values, show, customMessage);

  @override
  String toString() {
    return 'NotificationTemporaryState(action: $action, values: $values, show: $show, customMessage: $customMessage)';
  }
}