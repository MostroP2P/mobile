import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/user_info.dart';

class Peer implements Payload {
  final String publicKey;

  /// Reputation snapshot forwarded by the daemon. An empty [publicKey] with a
  /// non-null [reputation] is the taker-reputation notice sent to the maker
  /// before the counterpart's trade key is revealed.
  final UserInfo? reputation;

  Peer({required this.publicKey, this.reputation}) {
    // Empty is allowed: reputation-only notices carry no pubkey on purpose.
    // Basic validation for hex string format (64 characters for secp256k1)
    if (publicKey.isNotEmpty &&
        (publicKey.length != 64 ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(publicKey))) {
      throw ArgumentError(
          'Invalid public key format: must be 64-character hex string');
    }
  }

  factory Peer.fromJson(Map<String, dynamic> json) {
    try {
      final pubkey = json['pubkey'];
      if (pubkey == null) {
        throw FormatException('Missing required field: pubkey');
      }
      if (pubkey is! String) {
        throw FormatException(
            'Invalid pubkey type: expected String, got ${pubkey.runtimeType}');
      }

      final reputationJson = json['reputation'];
      return Peer(
        publicKey: pubkey,
        reputation: reputationJson is Map<String, dynamic>
            ? UserInfo.fromJson(reputationJson)
            : null,
      );
    } catch (e) {
      throw FormatException('Failed to parse Peer from JSON: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: {
        'pubkey': publicKey,
        if (reputation != null) 'reputation': reputation!.toJson(),
      }
    };
  }

  @override
  String get type => 'peer';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer &&
        other.publicKey == publicKey &&
        other.reputation == reputation;
  }

  @override
  int get hashCode => Object.hash(publicKey, reputation);

  @override
  String toString() => 'Peer(publicKey: $publicKey, reputation: $reputation)';
}
