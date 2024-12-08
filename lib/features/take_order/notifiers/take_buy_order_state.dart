import 'package:equatable/equatable.dart';

enum TakeBuyOrderStatus {
  initial,
  payInvoice,
  loading,
  error,
  cancelled,
  done,
}

class TakeBuyOrderState extends Equatable {
  final TakeBuyOrderStatus status;
  final String? errorMessage;
  final String? orderId;
  final int? invoiceAmount;

  const TakeBuyOrderState({
    this.orderId,
    this.status = TakeBuyOrderStatus.initial,
    this.errorMessage,
    this.invoiceAmount,
  });

  const TakeBuyOrderState._({
    this.orderId,
    required this.status,
    this.errorMessage,
    this.invoiceAmount,
  });

  /// Creates a copy with optional modifications
  TakeBuyOrderState copyWith({
    String? orderId,
    TakeBuyOrderStatus? status,
    String? errorMessage,
    int? invoiceAmount,
  }) {
    return TakeBuyOrderState._(
      orderId: orderId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      invoiceAmount: invoiceAmount,
    );
  }

  @override
  List<Object?> get props => [orderId, status, errorMessage, invoiceAmount];
}
