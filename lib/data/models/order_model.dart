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
  final double satsAmount;
  final String sellerName;
  final double sellerRating;
  final int sellerReviewCount;
  final String sellerAvatar;
  final double exchangeRate;
  final double buyerSatsAmount;
  final double buyerFiatAmount;
  final String status;

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
    required this.satsAmount,
    required this.sellerName,
    required this.sellerRating,
    required this.sellerReviewCount,
    required this.sellerAvatar,
    required this.exchangeRate,
    required this.buyerSatsAmount,
    required this.buyerFiatAmount,
    required this.status,
  });

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
      satsAmount: json['satsAmount'].toDouble(),
      sellerName: json['sellerName'],
      sellerRating: json['sellerRating'].toDouble(),
      sellerReviewCount: json['sellerReviewCount'],
      sellerAvatar: json['sellerAvatar'],
      exchangeRate: json['exchangeRate'].toDouble(),
      buyerSatsAmount: json['buyerSatsAmount'].toDouble(),
      buyerFiatAmount: json['buyerFiatAmount'].toDouble(),
      status: json['status'],
    );
  }

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
      'satsAmount': satsAmount,
      'sellerName': sellerName,
      'sellerRating': sellerRating,
      'sellerReviewCount': sellerReviewCount,
      'sellerAvatar': sellerAvatar,
      'exchangeRate': exchangeRate,
      'buyerSatsAmount': buyerSatsAmount,
      'buyerFiatAmount': buyerFiatAmount,
      'status': status,
    };
  }
}
