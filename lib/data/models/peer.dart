import 'package:mostro_mobile/data/models/payload.dart';

class Peer implements Payload {
  final String publicKey;

  Peer({required this.publicKey});

  factory Peer.fromJson(Map<String, dynamic> json) {
    final pubkey = json['pubkey'];
    if (pubkey == null || pubkey is! String) {
      throw FormatException('Invalid or missing pubkey in JSON');
    }
    return Peer(
      publicKey: pubkey,
    );
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
}
