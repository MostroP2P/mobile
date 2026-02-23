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
  /// Tracks the order that originated this session when it represents
  /// the preemptive child generated from a range order release.
  String? parentOrderId;
  Role? role;
  Peer? _peer;
  NostrKeyPairs? _sharedKey;
  String? _adminPubkey;
  NostrKeyPairs? _adminSharedKey;

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.parentOrderId,
    this.role,
    Peer? peer,
    String? adminPeer,
  }) {
    _peer = peer;
    if (peer != null) {
      _sharedKey = NostrUtils.computeSharedKey(
        tradeKey.private,
        peer.publicKey,
      );
    }
    if (adminPeer != null) {
      setAdminPeer(adminPeer);
    }
  }

  Map<String, dynamic> toJson() => {
        'trade_key': tradeKey.public,
        'key_index': keyIndex,
        'full_privacy': fullPrivacy,
        'start_time': startTime.toIso8601String(),
        'order_id': orderId,
        'parent_order_id': parentOrderId,
        'role': role?.value,
        'peer': peer?.publicKey,
        'admin_peer': _adminPubkey,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      final requiredFields = ['master_key', 'trade_key', 'key_index', 'full_privacy', 'start_time'];
      for (final field in requiredFields) {
        if (!json.containsKey(field) || json[field] == null) {
          throw FormatException('Missing required field: $field');
        }
      }

      // Parse keyIndex
      final keyIndexValue = json['key_index'];
      int keyIndex;
      if (keyIndexValue is int) {
        keyIndex = keyIndexValue;
      } else if (keyIndexValue is String) {
        keyIndex = int.tryParse(keyIndexValue) ??
            (throw FormatException('Invalid key_index format: $keyIndexValue'));
      } else {
        throw FormatException('Invalid key_index type: ${keyIndexValue.runtimeType}');
      }

      if (keyIndex < 0) {
        throw FormatException('Key index cannot be negative: $keyIndex');
      }

      // Validate key pair fields  
      final masterKeyValue = json['master_key'];  
      final tradeKeyValue = json['trade_key'];  
      if (masterKeyValue is! NostrKeyPairs) {  
        throw FormatException('Invalid master_key type: ${masterKeyValue.runtimeType}');  
      }  
      if (tradeKeyValue is! NostrKeyPairs) {  
        throw FormatException('Invalid trade_key type: ${tradeKeyValue.runtimeType}');  
      }  

      // Parse fullPrivacy
      final fullPrivacyValue = json['full_privacy'];
      bool fullPrivacy;
      if (fullPrivacyValue is bool) {
        fullPrivacy = fullPrivacyValue;
      } else if (fullPrivacyValue is String) {
        fullPrivacy = fullPrivacyValue.toLowerCase() == 'true';
      } else {
        throw FormatException('Invalid full_privacy type: ${fullPrivacyValue.runtimeType}');
      }

      // Parse startTime
      final startTimeValue = json['start_time'];
      DateTime startTime;
      if (startTimeValue is String) {
        if (startTimeValue.isEmpty) {
          throw FormatException('Start time string cannot be empty');
        }
        startTime = DateTime.tryParse(startTimeValue) ??
            (throw FormatException('Invalid start_time format: $startTimeValue'));
      } else {
        throw FormatException('Invalid start_time type: ${startTimeValue.runtimeType}');
      }

      // Parse optional role
      Role? role;
      final roleValue = json['role'];
      if (roleValue != null) {
        if (roleValue is String && roleValue.isNotEmpty) {
          role = Role.fromString(roleValue);
        } else if (roleValue is! String) {
          throw FormatException('Invalid role type: ${roleValue.runtimeType}');
        }
      }

      // Parse optional peer
      Peer? peer;
      final peerValue = json['peer'];
      if (peerValue != null) {
        if (peerValue is String && peerValue.isNotEmpty) {
          peer = Peer(publicKey: peerValue);
        } else if (peerValue is! String) {
          throw FormatException('Invalid peer type: ${peerValue.runtimeType}');
        }
      }

      // Parent order reference (only set for range order child sessions)
      String? parentOrderId;
      final parentOrderValue = json['parent_order_id'];
      if (parentOrderValue != null) {
        if (parentOrderValue is String && parentOrderValue.isNotEmpty) {
          parentOrderId = parentOrderValue;
        } else if (parentOrderValue is! String) {
          throw FormatException(
            'Invalid parent_order_id type: ${parentOrderValue.runtimeType}',
          );
        }
      }

      // Parse optional admin peer
      String? adminPeer;
      final adminPeerValue = json['admin_peer'];
      if (adminPeerValue != null) {
        if (adminPeerValue is String && adminPeerValue.isNotEmpty) {
          adminPeer = adminPeerValue;
        }
      }

      return Session(
        masterKey: masterKeyValue,
        tradeKey: tradeKeyValue,
        keyIndex: keyIndex,
        fullPrivacy: fullPrivacy,
        startTime: startTime,
        orderId: json['order_id']?.toString(),
        parentOrderId: parentOrderId,
        role: role,
        peer: peer,
        adminPeer: adminPeer,
      );
    } catch (e) {
      throw FormatException('Failed to parse Session from JSON: $e');
    }
  }

  NostrKeyPairs? get sharedKey => _sharedKey;

  String? get adminPubkey => _adminPubkey;
  NostrKeyPairs? get adminSharedKey => _adminSharedKey;

  /// Compute and store the admin shared key via ECDH
  void setAdminPeer(String adminPubkey) {
    _adminPubkey = adminPubkey;
    _adminSharedKey = NostrUtils.computeSharedKey(
      tradeKey.private,
      adminPubkey,
    );
  }

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
