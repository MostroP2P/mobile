import 'package:mostro_mobile/data/models/payload.dart';

class Peer implements Payload {
  final String publicKey;

  Peer({required this.publicKey}) {
    if (publicKey.isEmpty) {
      throw ArgumentError('Public key cannot be empty');
    }
    // Basic validation for hex string format (64 characters for secp256k1)
    if (publicKey.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(publicKey)) {
      throw ArgumentError('Invalid public key format: must be 64-character hex string');
    }
  }

  factory Peer.fromJson(Map<String, dynamic> json) {
    try {
      final pubkey = json['pubkey'];
      if (pubkey == null) {
        throw FormatException('Missing required field: pubkey');
      }
      if (pubkey is! String) {
        throw FormatException('Invalid pubkey type: expected String, got ${pubkey.runtimeType}');
      }
      if (pubkey.isEmpty) {
        throw FormatException('Public key cannot be empty');
      }
      
      return Peer(publicKey: pubkey);
    } catch (e) {
      throw FormatException('Failed to parse Peer from JSON: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: {
        'pubkey': publicKey,
      }
    };
  }

  @override
  String get type => 'peer';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.publicKey == publicKey;
  }
  
  @override
  int get hashCode => publicKey.hashCode;
  
  @override
  String toString() => 'Peer(publicKey: $publicKey)';
}
