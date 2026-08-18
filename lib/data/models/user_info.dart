/// Reputation snapshot of a counterpart, as forwarded by the Mostro daemon
/// inside a Peer payload (mostro-core `UserInfo`). Zeroed values mean either
/// a brand-new user or a full-privacy taker — indistinguishable on the wire.
class UserInfo {
  final double rating;
  final int reviews;
  final int operatingDays;

  const UserInfo({
    required this.rating,
    required this.reviews,
    required this.operatingDays,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      operatingDays: (json['operating_days'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'reviews': reviews,
        'operating_days': operatingDays,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo &&
          other.rating == rating &&
          other.reviews == reviews &&
          other.operatingDays == operatingDays;

  @override
  int get hashCode => Object.hash(rating, reviews, operatingDays);

  @override
  String toString() =>
      'UserInfo(rating: $rating, reviews: $reviews, operatingDays: $operatingDays)';
}
