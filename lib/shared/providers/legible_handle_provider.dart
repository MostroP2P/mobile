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
/// 
/// Returns a fallback handle if the input is invalid or cannot be parsed.
String deterministicHandleFromHexKey(String hexKey) {
  // Input validation
  if (hexKey.isEmpty) {
    return _generateFallbackHandle('empty');
  }

  // Clean and validate hex string
  final cleanHex = hexKey.toLowerCase().trim();
  
  // Check if it's a valid hex string (only 0-9, a-f characters)
  final hexRegex = RegExp(r'^[0-9a-f]+$');
  if (!hexRegex.hasMatch(cleanHex)) {
    return _generateFallbackHandle(cleanHex);
  }

  // For shorter strings, pad with zeros to avoid parsing errors
  // For longer strings, truncate to 64 characters
  String paddedHex;
  if (cleanHex.length < 64) {
    paddedHex = cleanHex.padLeft(64, '0');
  } else if (cleanHex.length > 64) {
    paddedHex = cleanHex.substring(0, 64);
  } else {
    paddedHex = cleanHex;
  }

  try {
    // 1) Parse the 64-char hex into a BigInt.
    //    Because it's 32 bytes, there's up to 256 bits of data here.
    final pubKeyBigInt = BigInt.parse(paddedHex, radix: 16);

    // 2) Use modulo arithmetic to pick an adjective and a noun.
    final adjectivesCount = kAdjectives.length;
    final nounsCount = kNouns.length;

    final indexAdjective = pubKeyBigInt % BigInt.from(adjectivesCount);
    final indexNoun =
        (pubKeyBigInt ~/ BigInt.from(adjectivesCount)) % BigInt.from(nounsCount);

    final adjective = kAdjectives[indexAdjective.toInt()];
    final noun = kNouns[indexNoun.toInt()];

    return '$adjective-$noun';
  } catch (e) {
    // If BigInt parsing fails, generate a fallback handle
    return _generateFallbackHandle(cleanHex);
  }
}

/// Generate a fallback handle when hex parsing fails
/// Uses a simple hash-based approach for consistency
String _generateFallbackHandle(String input) {
  // Use string hash for deterministic selection
  final hash = input.hashCode.abs();
  final adjective = kAdjectives[hash % kAdjectives.length];
  final noun = kNouns[(hash ~/ kAdjectives.length) % kNouns.length];
  return '$adjective-$noun';
}

final nickNameProvider = Provider.family<String, String>(
    (ref, pubkey) => deterministicHandleFromHexKey(pubkey));
