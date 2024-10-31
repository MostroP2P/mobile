import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;

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
  final String status;
  final double satsAmount;
  final String sellerName;
  final double sellerRating;
  final int sellerReviewCount;
  final String sellerAvatar;
  final double exchangeRate;
  final double buyerSatsAmount;
  final double buyerFiatAmount;

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
    required this.status,
    required this.satsAmount,
    required this.sellerName,
    required this.sellerRating,
    required this.sellerReviewCount,
    required this.sellerAvatar,
    required this.exchangeRate,
    required this.buyerSatsAmount,
    required this.buyerFiatAmount,
  });

  // Método para crear una instancia de OrderModel desde un JSON
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      type: json['type'],
      user: json['user'],
      rating: json['rating'].toDouble(),
      ratingCount: json['rating_count'],
      amount: json['amount'],
      currency: json['currency'],
      fiatAmount: json['fiat_amount'].toDouble(),
      fiatCurrency: json['fiat_currency'],
      paymentMethod: json['payment_method'],
      timeAgo: json['time_ago'],
      premium: json['premium'],
      status: json['status'],
      satsAmount: json['sats_amount'].toDouble(),
      sellerName: json['sellerName'],
      sellerRating: json['seller_rating'].toDouble(),
      sellerReviewCount: json['seller_review_count'],
      sellerAvatar: json['seller_avatar'],
      exchangeRate: json['exchange_rate'].toDouble(),
      buyerSatsAmount: json['buyer_sats_amount'].toDouble(),
      buyerFiatAmount: json['buyer_fiat_amount'].toDouble(),
    );
  }

  // Método para convertir una instancia de OrderModel a JSON
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
      'status': status,
      'satsAmount': satsAmount,
      'sellerName': sellerName,
      'sellerRating': sellerRating,
      'sellerReviewCount': sellerReviewCount,
      'sellerAvatar': sellerAvatar,
      'exchangeRate': exchangeRate,
      'buyerSatsAmount': buyerSatsAmount,
      'buyerFiatAmount': buyerFiatAmount,
    };
  }

  // Método para crear una instancia de OrderModel desde las Tags de un Event
  factory OrderModel.fromEventTags(List<List<String>> tags) {
    final Map<String, dynamic> tagMap = {};

    for (var tag in tags) {
      if (tag.length >= 2) {
        final key = tag[0];
        final value = tag.sublist(1);

        if (tagMap.containsKey(key)) {
          if (tagMap[key] is List) {
            tagMap[key].addAll(value);
          } else {
            tagMap[key] = [tagMap[key], ...value];
          }
        } else {
          tagMap[key] = value.length == 1 ? value.first : value;
        }
      }
    }

    String getString(String key) {
      if (!tagMap.containsKey(key)) return '';
      final value = tagMap[key];
      if (value is String) return value;
      if (value is List<String>) return value.join(', ');
      return '';
    }

    int getInt(String key, [int defaultValue = 0]) {
      final value = getString(key);
      return int.tryParse(value) ?? defaultValue;
    }

    double getDouble(String key, [double defaultValue = 0.0]) {
      final value = getString(key);
      return double.tryParse(value) ?? defaultValue;
    }

    double parseRating(String ratingJson) {
      if (ratingJson.isEmpty) return 0.0;
      try {
        final Map<String, dynamic> ratingMap = json.decode(ratingJson);
        return (ratingMap['total_rating'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error parsing rating JSON: $e');
        return 0.0;
      }
    }

    final int expirationTimestamp = getInt('expiration');
    final String timeAgoStr = _timeAgo(expirationTimestamp);
    final String name = getString('name').isEmpty ? "anon" : getString('name');

    try {
      return OrderModel(
        id: getString('d'),
        type: getString('k'),
        user: name,
        rating: parseRating(getString('rating')),
        ratingCount: getInt('rating_count'),
        amount: getInt('amt'),
        currency: getString('f'),
        fiatAmount: getDouble('fa'),
        fiatCurrency: getString('f'),
        paymentMethod: getString('pm'),
        timeAgo: timeAgoStr,
        premium: getString('premium'),
        status: getString('s'),
        satsAmount: getDouble('sats_amount'),
        sellerName: getString('seller_name'),
        sellerRating: getDouble('seller_rating'),
        sellerReviewCount: getInt('seller_review_count'),
        sellerAvatar: getString('seller_avatar'),
        exchangeRate: getDouble('exchange_rate'),
        buyerSatsAmount: getDouble('buyer_sats_amount'),
        buyerFiatAmount: getDouble('buyer_fiat_amount'),
      );
    } catch (e) {
      print('Error creating OrderModel from tags: $e');
      throw const FormatException('Invalid tags format for OrderModel');
    }
  }
}

String _timeAgo(int timestamp) {
  final DateTime eventTime =
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          .subtract(Duration(hours: 24));
  return timeago.format(eventTime, allowFromNow: true);
}
