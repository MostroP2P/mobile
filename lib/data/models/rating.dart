import 'dart:convert';

class Rating {
  final int totalReviews;
  final double totalRating;
  final int lastRating;
  final int maxRate;
  final int minRate;

  const Rating({
    required this.totalReviews,
    required this.totalRating,
    required this.lastRating,
    required this.maxRate,
    required this.minRate,
  });

  factory Rating.deserialized(String data) {
    if (data.isEmpty) {
      throw FormatException('Empty data string provided');
    }

    if (data == 'none') {
      return Rating.empty();
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return Rating(
        totalReviews: _parseInt(json, 'total_reviews'),
        totalRating: _parseDouble(json, 'total_rating'),
        lastRating: _parseInt(json, 'last_rating'),
        maxRate: _parseInt(json, 'max_rate'),
        minRate: _parseInt(json, 'min_rate'),
      );
    } catch (e) {
      throw FormatException('Failed to parse rating data: $e');
    }
  }

  static int _parseInt(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is int) return value;
    if (value is double) return value.toInt();
    throw FormatException('Invalid value for $field: $value');
  }

  static double _parseDouble(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    throw FormatException('Invalid value for $field: $value');
  }

  static Rating empty() {
    return const Rating(
      totalReviews: 0,
      totalRating: 0.0,
      lastRating: 0,
      maxRate: 0,
      minRate: 0,
    );
  }
}