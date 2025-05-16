import 'dart:convert';

class Rating {
  final int totalReviews;
  final double totalRating;
  final int lastRating;
  final int maxRate;
  final int minRate;
  final int days;

  const Rating({
    required this.totalReviews,
    required this.totalRating,
    required this.lastRating,
    required this.maxRate,
    required this.minRate,
    required this.days,
  });

  factory Rating.deserialized(String data) {
    if (data.isEmpty) {
      throw FormatException('Empty data string provided');
    }

    if (data == 'none') {
      return Rating.empty();
    }

    try {
      final json = jsonDecode(data);

      if (json is List &&
          json.length > 1 &&
          json[0] == 'rating' &&
          json[1] is Map) {
        final Map<String, dynamic> ratingData = json[1] as Map<String, dynamic>;
        return Rating(
          totalReviews: _parseIntFromNestedJson(ratingData, 'total_reviews'),
          totalRating: _parseDoubleFromNestedJson(ratingData, 'total_rating'),
          days: _parseIntFromNestedJson(ratingData, 'days'),
          lastRating: 0,
          maxRate: 5,
          minRate: 1,
        );
      } else if (json is Map<String, dynamic>) {
        return Rating(
          totalReviews: _parseInt(json, 'total_reviews'),
          totalRating: _parseDouble(json, 'total_rating'),
          lastRating: _parseInt(json, 'last_rating'),
          maxRate: _parseInt(json, 'max_rate'),
          minRate: _parseInt(json, 'min_rate'),
          days: _parseInt(json, 'days', defaultValue: 0),
        );
      } else {
        return Rating.empty();
      }
    } catch (e) {
      return Rating.empty();
    }
  }

  static int _parseInt(Map<String, dynamic> json, String field,
      {int defaultValue = 0}) {
    final value = json[field];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    try {
      return int.parse(value.toString());
    } catch (_) {
      return defaultValue;
    }
  }

  static int _parseIntFromNestedJson(Map<String, dynamic> json, String field,
      {int defaultValue = 0}) {
    final value = json[field];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    try {
      return int.parse(value.toString());
    } catch (_) {
      return defaultValue;
    }
  }

  static double _parseDouble(Map<String, dynamic> json, String field,
      {double defaultValue = 0.0}) {
    final value = json[field];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return defaultValue;
    }
  }

  static double _parseDoubleFromNestedJson(
      Map<String, dynamic> json, String field,
      {double defaultValue = 0.0}) {
    final value = json[field];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return defaultValue;
    }
  }

  static Rating empty() {
    return const Rating(
      totalReviews: 0,
      totalRating: 0.0,
      lastRating: 0,
      maxRate: 5,
      minRate: 1,
      days: 0,
    );
  }
}
