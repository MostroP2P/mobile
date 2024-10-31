import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:equatable/equatable.dart';

enum OrderDetailsStatus { initial, loading, loaded, error, cancelled, done }

class OrderDetailsState extends Equatable {
  final OrderDetailsStatus status;
  final NostrEvent? order;
  final String? errorMessage;

  const OrderDetailsState({
    this.status = OrderDetailsStatus.initial,
    this.order,
    this.errorMessage,
  });

  OrderDetailsState copyWith({
    OrderDetailsStatus? status,
    NostrEvent? order,
    String? errorMessage,
  }) {
    return OrderDetailsState(
      status: status ?? this.status,
      order: order ?? this.order,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, order, errorMessage];
}
