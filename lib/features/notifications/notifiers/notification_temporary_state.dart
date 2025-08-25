import 'package:collection/collection.dart';
import 'package:mostro_mobile/data/enums.dart';

class TemporaryNotification {
  final Action? action;
  final Map<String, dynamic> values;
  final bool show;
  final String? customMessage;

  const TemporaryNotification({
    this.action,
    this.values = const {},
    this.show = false,
    this.customMessage,
  });

  TemporaryNotification copyWith({
    Action? action,
    Map<String, dynamic>? values,
    bool? show,
    String? customMessage,
  }) {
    return TemporaryNotification(
      action: action ?? this.action,
      values: values ?? this.values,
      show: show ?? this.show,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporaryNotification &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          const DeepCollectionEquality().equals(values, other.values) &&
          show == other.show &&
          customMessage == other.customMessage;

  @override
  int get hashCode => Object.hash(action, const DeepCollectionEquality().hash(values), show, customMessage);

  @override
  String toString() {
    return 'TemporaryNotification(action: $action, values: $values, show: $show, customMessage: $customMessage)';
  }
}