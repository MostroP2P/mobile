import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';

/// Represents a parsed NWC (Nostr Wallet Connect) connection URI.
///
/// Format: `nostr+walletconnect://<wallet_pubkey>?relay=<relay_url>&secret=<secret>&lud16=<lud16>`
class NwcConnection extends Equatable {
  /// The wallet service's 32-byte hex-encoded public key.
  final String walletPubkey;

  /// One or more relay URLs where the wallet service is listening.
  final List<String> relayUrls;

  /// The 32-byte hex-encoded secret key used by the client to sign and encrypt.
  final String secret;

  /// Optional lightning address for the user's profile.
  final String? lud16;

  const NwcConnection({
    required this.walletPubkey,
    required this.relayUrls,
    required this.secret,
    this.lud16,
  });

  /// Parses a `nostr+walletconnect://` URI string into an [NwcConnection].
  ///
  /// Throws [NwcInvalidUriException] if the URI is malformed or missing
  /// required parameters.
  factory NwcConnection.fromUri(String uriString) {
    final trimmed = uriString.trim();

    if (!trimmed.startsWith('nostr+walletconnect://')) {
      throw const NwcInvalidUriException(
        'URI must start with nostr+walletconnect://',
      );
    }

    // Replace scheme so Dart's Uri parser can handle it
    final normalizedUri = trimmed.replaceFirst(
      'nostr+walletconnect://',
      'nostrwalletconnect://',
    );

    final Uri uri;
    try {
      uri = Uri.parse(normalizedUri);
    } catch (e) {
      throw NwcInvalidUriException('Failed to parse URI: $e');
    }

    // Extract wallet pubkey from host
    final walletPubkey = uri.host;
    if (walletPubkey.isEmpty) {
      throw const NwcInvalidUriException('Missing wallet pubkey in URI');
    }

    if (!_isValidHexKey(walletPubkey)) {
      throw const NwcInvalidUriException(
        'Invalid wallet pubkey: must be a 64-character hex string',
      );
    }

    // Extract relay URLs (can appear multiple times)
    final relayUrls = uri.queryParametersAll['relay'];
    if (relayUrls == null || relayUrls.isEmpty) {
      throw const NwcInvalidUriException(
        'Missing required "relay" parameter in URI',
      );
    }

    for (final relay in relayUrls) {
      if (!relay.startsWith('wss://') && !relay.startsWith('ws://')) {
        throw NwcInvalidUriException(
          'Invalid relay URL: $relay (must start with wss:// or ws://)',
        );
      }
    }

    // Extract secret
    final secret = uri.queryParameters['secret'];
    if (secret == null || secret.isEmpty) {
      throw const NwcInvalidUriException(
        'Missing required "secret" parameter in URI',
      );
    }

    if (!_isValidHexKey(secret)) {
      throw const NwcInvalidUriException(
        'Invalid secret: must be a 64-character hex string',
      );
    }

    // Extract optional lud16
    final lud16 = uri.queryParameters['lud16'];

    return NwcConnection(
      walletPubkey: walletPubkey,
      relayUrls: relayUrls,
      secret: secret,
      lud16: (lud16 != null && lud16.isNotEmpty) ? lud16 : null,
    );
  }

  /// Converts this connection back to a URI string.
  String toUri() {
    final params = <String>[];
    for (final relay in relayUrls) {
      params.add('relay=${Uri.encodeComponent(relay)}');
    }
    params.add('secret=$secret');
    if (lud16 != null) {
      params.add('lud16=${Uri.encodeComponent(lud16!)}');
    }
    return 'nostr+walletconnect://$walletPubkey?${params.join('&')}';
  }

  static bool _isValidHexKey(String key) {
    if (key.length != 64) return false;
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key);
  }

  @override
  List<Object?> get props => [walletPubkey, relayUrls, secret, lud16];

  @override
  String toString() =>
      'NwcConnection(walletPubkey: ${walletPubkey.substring(0, 8)}..., '
      'relays: $relayUrls, lud16: $lud16)';
}
