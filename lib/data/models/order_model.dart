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
  // Nuevas propiedades
  final String sellerAvatar;
  final String sellerName;
  final String sellerRating;
  final int sellerReviewCount;
  final String satsAmount;
  final String exchangeRate;
  final String buyerSatsAmount;
  final String buyerFiatAmount;

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
    // Inicialización de las nuevas propiedades
    required this.sellerAvatar,
    required this.sellerName,
    required this.sellerRating,
    required this.sellerReviewCount,
    required this.satsAmount,
    required this.exchangeRate,
    required this.buyerSatsAmount,
    required this.buyerFiatAmount,
  });
}
