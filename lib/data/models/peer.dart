import 'package:mostro_mobile/data/models/content.dart';

class Peer implements Content {
  final String publicKey;

  Peer({required this.publicKey});

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      publicKey: json['pubkey'] as String,
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
  String get type => 'Peer';
}
