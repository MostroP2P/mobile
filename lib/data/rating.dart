import 'dart:convert';

class Rating {
  final int totalReviews;
  final double totalRating;
  final int lastRating;
  final int maxRate;
  final int minRate;

  Rating(
      {required this.totalReviews,
      required this.totalRating,
      required this.lastRating,
      required this.maxRate,
      required this.minRate});

  factory Rating.deserialized(String data) {
    if (data == 'none') {
      return Rating(
          totalReviews: 0,
          totalRating: 0.0,
          lastRating: 0,
          maxRate: 0,
          minRate: 0);
    }
    final json = jsonDecode(data) as Map<String, dynamic>;
    return Rating(
        totalReviews: json['rating']['total_reviews'],
        totalRating: json['rating']['total_rating'],
        lastRating: json['rating']['last_rating'],
        maxRate: json['rating']['max_rate'],
        minRate: json['rating']['min_rate']);
  }
}
