import 'package:mostro_mobile/data/models/payload.dart';

import 'package:equatable/equatable.dart';

class PaymentFailed extends Equatable implements Payload {
  final int paymentAttempts;
  final int paymentRetriesInterval;

  const PaymentFailed({
    required this.paymentAttempts,
    required this.paymentRetriesInterval,
  });

  @override
  List<Object?> get props => [paymentAttempts, paymentRetriesInterval];

  factory PaymentFailed.fromJson(Map<String, dynamic> json) {
    return PaymentFailed(
      paymentAttempts: json['payment_attempts'] as int,
      paymentRetriesInterval: json['payment_retries_interval'] as int,
    );
  }

  @override
  String get type => 'payment_failed';

  @override
  Map<String, dynamic> toJson() {
    return {
      type: {
        'payment_attempts': paymentAttempts,
        'payment_retries_interval': paymentRetriesInterval,
      },
    };
  }
}
