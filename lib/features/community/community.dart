import 'package:mostro_mobile/core/config/communities.dart';

/// A community with its static config and dynamic metadata from Nostr events.
class Community {
  final String pubkey;
  final String region;
  final List<SocialLink> social;
  final String? website;

  // From kind 0 (Nostr profile)
  final String? name;
  final String? about;
  final String? picture;

  // From kind 38385 (Mostro info)
  final bool hasTradeInfo;
  final List<String> currencies;
  final int? minAmount;
  final int? maxAmount;
  final double? fee;

  const Community({
    required this.pubkey,
    required this.region,
    this.social = const [],
    this.website,
    this.name,
    this.about,
    this.picture,
    this.hasTradeInfo = false,
    this.currencies = const [],
    this.minAmount,
    this.maxAmount,
    this.fee,
  });

  /// Create from static config (before Nostr data is fetched).
  factory Community.fromConfig(CommunityConfig config) {
    return Community(
      pubkey: config.pubkey,
      region: config.region,
      social: config.social,
      website: config.website,
    );
  }

  /// Display name: kind 0 name, or region as fallback.
  String get displayName => name ?? region;

  /// Copy with updated metadata fields.
  Community copyWith({
    String? name,
    String? about,
    String? picture,
    bool? hasTradeInfo,
    List<String>? currencies,
    int? minAmount,
    int? maxAmount,
    double? fee,
  }) {
    return Community(
      pubkey: pubkey,
      region: region,
      social: social,
      website: website,
      name: name ?? this.name,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      hasTradeInfo: hasTradeInfo ?? this.hasTradeInfo,
      currencies: currencies ?? this.currencies,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      fee: fee ?? this.fee,
    );
  }
}
