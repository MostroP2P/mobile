class OrderModel {
  final String user;
  final String rating;
  final int ratingCount;
  final String timeAgo;
  final String amount;
  final String currency;
  final String fiatAmount;
  final String fiatCurrency;
  final String premium;
  final String paymentMethod;
  final String type;

  OrderModel({
    required this.user,
    required this.rating,
    required this.ratingCount,
    required this.timeAgo,
    required this.amount,
    required this.currency,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.premium,
    required this.paymentMethod,
    required this.type,
  });
}
