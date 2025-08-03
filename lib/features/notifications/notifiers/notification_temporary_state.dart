import 'package:mostro_mobile/data/enums.dart';

class NotificationTemporaryState {
  final Action? action;
  final Map<String, dynamic> values;
  final bool show;

  const NotificationTemporaryState({
    this.action,
    this.values = const {},
    this.show = false,
  });

  NotificationTemporaryState copyWith({
    Action? action,
    Map<String, dynamic>? values,
    bool? show,
  }) {
    return NotificationTemporaryState(
      action: action ?? this.action,
      values: values ?? this.values,
      show: show ?? this.show,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTemporaryState &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          values == other.values &&
          show == other.show;

  @override
  int get hashCode => Object.hash(action, values, show);

  @override
  String toString() {
    return 'NotificationTemporaryState(action: $action, values: $values, show: $show)';
  }
}