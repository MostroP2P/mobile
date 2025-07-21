import 'package:mostro_mobile/data/models/payload.dart';

class RatingUser implements Payload {
  final int userRating;

  RatingUser({required this.userRating}) {
    if (userRating < 1 || userRating > 5) {
      throw ArgumentError('User rating must be between 1 and 5, got: $userRating');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: userRating,
    };
  }

  factory RatingUser.fromJson(dynamic json) {
    try {
      int rating;
      
      if (json is int) {
        rating = json;
      } else if (json is String) {
        rating = int.tryParse(json) ??
            (throw FormatException('Invalid rating format: $json'));
      } else if (json is Map<String, dynamic>) {
        final ratingValue = json['user_rating'] ?? json['rating'];
        if (ratingValue == null) {
          throw FormatException('Missing rating field in JSON object');
        }
        if (ratingValue is int) {
          rating = ratingValue;
        } else if (ratingValue is String) {
          rating = int.tryParse(ratingValue) ??
              (throw FormatException('Invalid rating format: $ratingValue'));
        } else {
          throw FormatException('Invalid rating type: ${ratingValue.runtimeType}');
        }
      } else {
        throw FormatException('Invalid JSON type for RatingUser: ${json.runtimeType}');
      }
      
      if (rating < 1 || rating > 5) {
        throw FormatException('Rating must be between 1 and 5, got: $rating');
      }
      
      return RatingUser(userRating: rating);
    } catch (e) {
      throw FormatException('Failed to parse RatingUser from JSON: $e');
    }
  }

  @override
  String get type => 'rating_user';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RatingUser && other.userRating == userRating;
  }
  
  @override
  int get hashCode => userRating.hashCode;
  
  @override
  String toString() => 'RatingUser(userRating: $userRating)';
}
