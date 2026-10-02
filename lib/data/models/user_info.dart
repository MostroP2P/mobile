import 'package:mostro_mobile/shared/utils/reputation_age.dart';

/// Reputation snapshot of a counterpart, as forwarded by the Mostro daemon
/// inside a Peer payload (mostro-core `UserInfo`). Zeroed values mean either
/// a brand-new user or a full-privacy taker — indistinguishable on the wire.
class UserInfo {
  final double rating;
  final int reviews;
  final int operatingDays;

  /// Day of the counterpart's first trade (Unix seconds, UTC day start), or
  /// null when the daemon predates the protocol's `since`.
  final int? since;

  const UserInfo({
    required this.rating,
    required this.reviews,
    required this.operatingDays,
    this.since,
  });

  /// Days on Mostro to show: counted from [since], else the deprecated
  /// [operatingDays].
  int get daysOnMostro =>
      reputationDaysOnMostro(since: since, fallbackDays: operatingDays);

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      operatingDays: (json['operating_days'] as num?)?.toInt() ?? 0,
      since: parseReputationSince(json['since']),
    );
  }

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'reviews': reviews,
        'operating_days': operatingDays,
        if (since != null) 'since': since,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo &&
          other.rating == rating &&
          other.reviews == reviews &&
          other.operatingDays == operatingDays &&
          other.since == since;

  @override
  int get hashCode => Object.hash(rating, reviews, operatingDays, since);

  @override
  String toString() =>
      'UserInfo(rating: $rating, reviews: $reviews, operatingDays: $operatingDays, since: $since)';
}
