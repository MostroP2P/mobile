import 'package:mostro_mobile/data/models/payload.dart';

class PaymentFailed implements Payload {
  final int paymentAttempts;
  final int paymentRetriesInterval;

  PaymentFailed({
    required this.paymentAttempts,
    required this.paymentRetriesInterval,
  });

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
