import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:equatable/equatable.dart';

enum OrderDetailsStatus {
  initial,
  loading,
  loaded,
  error,
  cancelled,
  done,
}

class OrderDetailsState extends Equatable {
  final OrderDetailsStatus status;
  final NostrEvent? order;
  final String? errorMessage;

  const OrderDetailsState({
    this.status = OrderDetailsStatus.initial,
    this.order, // Default value for nullable fields
    this.errorMessage,
  });

  const OrderDetailsState._({
    required this.status,
    this.order,
    this.errorMessage,
  });

  /// Initial state
  const OrderDetailsState.initial() : this._(status: OrderDetailsStatus.initial);

  /// Loading state
  const OrderDetailsState.loading() : this._(status: OrderDetailsStatus.loading);

  /// Loaded state with order data
  const OrderDetailsState.loaded(NostrEvent order)
      : this._(status: OrderDetailsStatus.loaded, order: order);

  /// Error state with an optional error message
  const OrderDetailsState.error(String errorMessage)
      : this._(status: OrderDetailsStatus.error, errorMessage: errorMessage);

  /// Cancelled state
  const OrderDetailsState.cancelled()
      : this._(status: OrderDetailsStatus.cancelled);

  /// Done state, e.g., for successful completion
  const OrderDetailsState.done()
      : this._(status: OrderDetailsStatus.done);

  /// Creates a copy with optional modifications
  OrderDetailsState copyWith({
    OrderDetailsStatus? status,
    NostrEvent? order,
    String? errorMessage,
  }) {
    return OrderDetailsState._(
      status: status ?? this.status,
      order: order ?? this.order,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, order, errorMessage];
}
