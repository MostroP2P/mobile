import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A small Dart "library" that generates a memorable, on-theme nickname
/// from a 32-byte (64-hex-char) public key string. Ideal for ephemeral
/// or No-KYC usage. Collisions are possible with many users; expand
/// lists for a bigger namespace if needed.

/// Some playful and thematic adjectives (Bitcoin/Nostr/privacy vibes + more).
const List<String> kAdjectives = [
  'shadowy',
  'orange',
  'lightning',
  'p2p',
  'noncustodial',
  'trustless',
  'unbanked',
  'atomic',
  'magic',
  'tor',
  'hidden',
  'incognito',
  'anonymous',
  'encrypted',
  'ghostly',
  'silent',
  'masked',
  'stealthy',
  'free',
  'nostalgic',
  'ephemeral',
  'sovereign',
  'unstoppable',
  'private',
  'censorshipresistant',
  'hush',
  'defiant',
  'subversive',
  'fiery',
  'subzero',
  'burning',
  'cosmic',
  'mighty',
  'whispering',
  'cyber',
  'rusty',
  'nihilistic',
  'mempool',
  'dark',
  'wicked',
  'spicy',
  'noKYC',
  'discreet',
  'loose',
  'boosted',
  'starving',
  'hungry',
  'orwellian',
  'bullish',
  'bearish',
];

/// Some nouns mixing animals, Bitcoin legends, Nostr references, & places.
const List<String> kNouns = [
  'wizard',
  'pirate',
  'zap',
  'node',
  'invoice',
  'nipster',
  'nomad',
  'sats',
  'bull',
  'bear',
  'whale',
  'frog',
  'gorilla',
  'nostrich',
  'halfinney',
  'hodlonaut',
  'satoshi',
  'nakamoto',
  'gigi',
  'samurai',
  'crusader',
  'tinkerer',
  'nostr',
  'pleb',
  'warrior',
  'ecdsa',
  'monkey',
  'wolf',
  'renegade',
  'minotaur',
  'phoenix',
  'dragon',
  'fiatjaf',
  'jackmallers',
  'roasbeef',
  'berlin',
  'tokyo',
  'buenosaires',
  'miami',
  'prague',
  'amsterdam',
  'lugano',
  'seoul',
  'bitcoinbeach',
  'odell',
  'bitcoinkid',
  'marty',
  'finney',
  'carnivore',
  'ape',
  'honeybadger',
];

/// Convert a 32-byte hex string (64 hex chars) into a fun, deterministic handle.
/// Example result: "shadowy-wizard", "noKYC-satoshi", etc.
String deterministicHandleFromHexKey(String hexKey) {
  // Validate that the input is a valid hex string
  if (hexKey.isEmpty) {
    return 'unknown-user';
  }
  
  // Clean the hex string (remove any non-hex characters)
  final cleanHexKey = hexKey.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  
  // If the cleaned string is empty or invalid, return a default handle
  if (cleanHexKey.isEmpty) {
    return 'invalid-key';
  }

  try {
    // 1) Parse the hex into a BigInt.
    //    Because it's 32 bytes, there's up to 256 bits of data here.
    final pubKeyBigInt = BigInt.parse(cleanHexKey, radix: 16);

    // 2) Use modulo arithmetic to pick an adjective and a noun.
    final adjectivesCount = kAdjectives.length;
    final nounsCount = kNouns.length;

    final indexAdjective = pubKeyBigInt % BigInt.from(adjectivesCount);
    final indexNoun =
        (pubKeyBigInt ~/ BigInt.from(adjectivesCount)) % BigInt.from(nounsCount);

    // 3) Return the hyphenated result.
    return '${kAdjectives[indexAdjective.toInt()]}-${kNouns[indexNoun.toInt()]}';
  } catch (e) {
    // If parsing fails, return a default handle
    return 'unparseable-key';
  }
}

final nickNameProvider = Provider.family<String, String>(
    (ref, pubkey) => deterministicHandleFromHexKey(pubkey));
