/// Social link for a community (Telegram, X, Instagram, etc.)
class SocialLink {
  final String type;
  final String url;

  const SocialLink({required this.type, required this.url});
}

/// Static configuration for a trusted Mostro community.
/// Metadata (name, about, picture) is fetched from Nostr kind 0 events.
class CommunityConfig {
  final String pubkey;
  final String region;
  final List<SocialLink> social;
  final String? website;

  const CommunityConfig({
    required this.pubkey,
    required this.region,
    this.social = const [],
    this.website,
  });
}

/// Default Mostro node pubkey (used when user skips community selection).
const String defaultMostroPubkey =
    '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

/// Trusted Mostro communities mirrored from mostro.community.
const List<CommunityConfig> trustedCommunities = [
  CommunityConfig(
    pubkey:
        '00000235a3e904cfe1213a8a54d6f1ec1bef7cc6bfaabd6193e82931ccf1366a',
    region: '\u{1F1E8}\u{1F1FA} Cuba',
    social: [SocialLink(type: 'telegram', url: 'https://t.me/Cuba_Bitcoin')],
    website: 'https://cubabitcoin.org/kmbalache/',
  ),
  CommunityConfig(
    pubkey:
        '0000cc02101ec29eea9ce623258752b9d7da66c27845ed26846dd0b0fc736b40',
    region: '\u{1F1EA}\u{1F1F8} Espa\u{00F1}a',
    social: [SocialLink(type: 'telegram', url: 'https://t.me/nostromostro')],
  ),
  CommunityConfig(
    pubkey:
        '00000978acc594c506976c655b6decbf2d4af25ffdaa6680f2a9568b0a88441b',
    region: '\u{1F1E8}\u{1F1F4} Colombia',
    social: [
      SocialLink(type: 'telegram', url: 'https://t.me/ColombiaP2P'),
      SocialLink(type: 'x', url: 'https://x.com/ColombiaP2P'),
    ],
  ),
  CommunityConfig(
    pubkey:
        '00007cb3305fb972f5cc83f83a8fbca1e64e93c9d1369880a9fd62ef95d23f91',
    region: '\u{1F1E7}\u{1F1F4} Bolivia',
    social: [
      SocialLink(type: 'telegram', url: 'https://t.me/btcxbolivia'),
      SocialLink(type: 'x', url: 'https://x.com/btcxbolivia'),
      SocialLink(
        type: 'instagram',
        url: 'https://www.instagram.com/btcxbolivia',
      ),
    ],
  ),
  CommunityConfig(
    pubkey: defaultMostroPubkey,
    region: '\u{1F310} Default',
    social: [],
  ),
];
