import 'package:mostro_mobile/data/models/payload.dart';

class RatingUser implements Payload {
  final int userRating;

  RatingUser({required this.userRating});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: userRating,
    };
  }

  factory RatingUser.fromJson(dynamic json) {
    return RatingUser(userRating: json as int);
  }

  @override
  String get type => 'rating_user';
}
