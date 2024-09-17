import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
  final String id;
  final String type; // 'buy' or 'sell'
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final double price;
  final String createdAt;
  final String userPubkey;

  const OrderModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.price,
    required this.createdAt,
    required this.userPubkey,
  });

  // Factory constructor para crear una instancia desde un Map (útil para JSON)
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String,
      price: (json['price'] as num).toDouble(),
      createdAt: json['created_at'] as String,
      userPubkey: json['user_pubkey'] as String,
    );
  }

  // Método para convertir la instancia a un Map (útil para JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      'price': price,
      'created_at': createdAt,
      'user_pubkey': userPubkey,
    };
  }

  // Método para crear una copia de la instancia con cambios opcionales
  OrderModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? currency,
    String? status,
    String? paymentMethod,
    double? price,
    String? createdAt,
    String? userPubkey,
  }) {
    return OrderModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      userPubkey: userPubkey ?? this.userPubkey,
    );
  }

  @override
  List<Object> get props => [
        id,
        type,
        amount,
        currency,
        status,
        paymentMethod,
        price,
        createdAt,
        userPubkey
      ];

  @override
  String toString() {
    return 'OrderModel(id: $id, type: $type, amount: $amount, currency: $currency, status: $status, paymentMethod: $paymentMethod, price: $price, createdAt: $createdAt, userPubkey: $userPubkey)';
  }
}
