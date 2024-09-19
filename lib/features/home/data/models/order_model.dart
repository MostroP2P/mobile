class OrderModel {
  final String id;
  final String type;
  final String user;
  final double rating;
  final int ratingCount;
  final int amount;
  final String currency;
  final double fiatAmount;
  final String fiatCurrency;
  final String paymentMethod;
  final String timeAgo;
  final String premium;

  OrderModel({
    required this.id,
    required this.type,
    required this.user,
    required this.rating,
    required this.ratingCount,
    required this.amount,
    required this.currency,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.paymentMethod,
    required this.timeAgo,
    required this.premium,
  });

  // Si necesitas crear una instancia de OrderModel desde un mapa (por ejemplo, al recibir datos de una API),
  // puedes usar un método factory como este:
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      type: json['type'],
      user: json['user'],
      rating: json['rating'].toDouble(),
      ratingCount: json['ratingCount'],
      amount: json['amount'],
      currency: json['currency'],
      fiatAmount: json['fiatAmount'].toDouble(),
      fiatCurrency: json['fiatCurrency'],
      paymentMethod: json['paymentMethod'],
      timeAgo: json['timeAgo'],
      premium: json['premium'],
    );
  }

  // Si necesitas convertir la instancia de OrderModel a un mapa (por ejemplo, para enviar datos a una API),
  // puedes usar un método como este:
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'user': user,
      'rating': rating,
      'ratingCount': ratingCount,
      'amount': amount,
      'currency': currency,
      'fiatAmount': fiatAmount,
      'fiatCurrency': fiatCurrency,
      'paymentMethod': paymentMethod,
      'timeAgo': timeAgo,
      'premium': premium,
    };
  }
}
