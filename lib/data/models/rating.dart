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
    if (data.isEmpty) {
      throw FormatException('Empty data string provided');
    }
    if (data == 'none') {
      return Rating(
          totalReviews: 0,
          totalRating: 0.0,
          lastRating: 0,
          maxRate: 0,
          minRate: 0);
    }
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final rating = json['rating'] as Map<String, dynamic>?;

      if (rating == null) {
        throw FormatException('Missing rating object in JSON');
      }

      return Rating(
        totalReviews: _parseIntField(rating, 'total_reviews'),
        totalRating: _parseDoubleField(rating, 'total_rating'),
        lastRating: _parseIntField(rating, 'last_rating'),
        maxRate: _parseIntField(rating, 'max_rate'),
        minRate: _parseIntField(rating, 'min_rate'),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse rating data: $e');
    }
  }
  static int _parseIntField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) {
      throw FormatException('Missing required field: $field');
    }
    if (value is! num) {
      throw FormatException(
          'Invalid type for $field: expected number, got ${value.runtimeType}');
    }
    return value.toInt();
  }

  static double _parseDoubleField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) {
      throw FormatException('Missing required field: $field');
    }
    if (value is! num) {
      throw FormatException(
          'Invalid type for $field: expected number, got ${value.runtimeType}');
    }
    return value.toDouble();
  }
}
