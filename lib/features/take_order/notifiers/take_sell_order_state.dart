import 'package:equatable/equatable.dart';

enum TakeSellOrderStatus {
  initial,
  addInvoice,
  loading,
  error,
  cancelled,
  done,
}

class TakeSellOrderState extends Equatable {
  final TakeSellOrderStatus status;
  final String? errorMessage;
  final String? orderId;
  final int? invoiceAmount;

  const TakeSellOrderState({
    this.orderId,
    this.status = TakeSellOrderStatus.initial,
    this.errorMessage,
    this.invoiceAmount,
  });

  const TakeSellOrderState._({
    this.orderId,
    required this.status,
    this.errorMessage,
    this.invoiceAmount,
  });

  /// Creates a copy with optional modifications
  TakeSellOrderState copyWith({
    String? orderId,
    TakeSellOrderStatus? status,
    String? errorMessage,
    int? invoiceAmount,
  }) {
    return TakeSellOrderState._(
      orderId: orderId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      invoiceAmount: invoiceAmount,
    );
  }

  @override
  List<Object?> get props => [orderId, status, errorMessage, invoiceAmount];
}
