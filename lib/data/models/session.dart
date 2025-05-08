import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Represents a User session
///
/// This class is used to store details of a user session
class Session {
  final NostrKeyPairs masterKey;
  final NostrKeyPairs tradeKey;
  final int keyIndex;
  final bool fullPrivacy;
  final DateTime startTime;
  String? orderId;
  Role? role;
  Peer? _peer;
  NostrKeyPairs? _sharedKey;

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.role,
    Peer? peer,
  }) {
    _peer = peer;
    if (peer != null) {
      _sharedKey = NostrUtils.computeSharedKey(
        tradeKey.private,
        peer.publicKey,
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'trade_key': tradeKey.public,
        'key_index': keyIndex,
        'full_privacy': fullPrivacy,
        'start_time': startTime.toIso8601String(),
        'order_id': orderId,
        'role': role?.value,
        'peer': peer?.publicKey,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      masterKey: json['master_key'],
      tradeKey: json['trade_key'],
      keyIndex: json['key_index'],
      fullPrivacy: json['full_privacy'],
      startTime: DateTime.parse(json['start_time']),
      orderId: json['order_id'],
      role: json['role'] != null ? Role.fromString(json['role']) : null,
      peer: json['peer'] != null ? Peer(publicKey: json['peer']) : null,
    );
  }

  NostrKeyPairs? get sharedKey => _sharedKey;

  Peer? get peer => _peer;

  set peer(Peer? newPeer) {
    if (newPeer == null) {
      _peer = null;
      _sharedKey = null;
      return;
    }
    _peer = newPeer;
    _sharedKey = NostrUtils.computeSharedKey(
      tradeKey.private,
      newPeer.publicKey,
    );
  }
}
