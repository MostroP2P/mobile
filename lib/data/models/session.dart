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
  String? disputeId;

  /// The order amount in satoshis as it stood when this session committed to
  /// the trade, or null when there was no resolved figure to pin.
  ///
  /// The settlement checks derive what a payment should be from the node's
  /// kind-38383 order event and kind-38385 info event, both of which are
  /// addressable and can be republished after the fact. Pinning the figures
  /// the user actually agreed to holds the check to those terms rather than
  /// to whatever the node last said.
  ///
  /// Null for a market-price or range order, whose sats figure the node only
  /// resolves after the take — there is nothing to pin at the moment of
  /// commitment, and those orders fall back to the live events.
  late final int? pinnedAmountSats;

  /// The node's fee rate when this session committed, on the same terms as
  /// [pinnedAmountSats].
  late final double? pinnedFeeRate;

  /// The currency, fiat figure and premium this session committed to.
  ///
  /// The independent market quote is priced from these three, and all three
  /// live in the same addressable kind-38383 event as the sats amount. Read
  /// live, they let a node make a shaved settlement quote exactly: resolve
  /// fewer sats than the trade was agreed at, then republish the premium so
  /// the quote lands on the shaved figure. Pinned, the quote prices what the
  /// user accepted.
  ///
  /// Null where there was nothing to pin — a session written before pinning
  /// existed, or an order event that had not arrived at commitment.
  late final String? pinnedFiatCode;
  late final int? pinnedFiatAmount;
  late final double? pinnedPremium;

  /// Whether the terms were pinned when this session committed.
  ///
  /// Together with the figures above: all of it is written once, in the
  /// constructor body, and never moved afterwards. That is what a pin is.
  ///
  /// Separates a session that pinned whatever there was to pin — possibly
  /// nothing, for a market-price order with no resolved sats, or for a
  /// commitment made before the info event arrived — from one written before
  /// pinning existed at all. Only the second has any business reading a term
  /// the node publishes later; for the first, an absent figure means the node
  /// could not supply it at the moment of agreement, and letting it supply
  /// one afterwards is the move pinning exists to stop.
  ///
  /// False for every session written by an earlier version, which keeps them
  /// behaving as they did.
  final bool termsPinned;

  /// Transient marker (never persisted): set while a maker-created order is in
  /// the anti-abuse bond limbo, so the shared pay-bond handler skips persisting
  /// the still-uncommitted session. Cleared and persisted on confirmation.
  bool bondPending = false;

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.parentOrderId,
    this.role,
    this.disputeId,
    int? pinnedAmountSats,
    double? pinnedFeeRate,
    String? pinnedFiatCode,
    int? pinnedFiatAmount,
    double? pinnedPremium,
    this.termsPinned = false,
    Peer? peer,
    String? adminPubkey,
  }) {
    // Normalized here rather than at each reader: a figure that cannot anchor
    // anything is the same as no figure, and the checks that consult these
    // fields have to agree on which is which.
    this.pinnedAmountSats =
        (pinnedAmountSats != null && pinnedAmountSats > 0)
            ? pinnedAmountSats
            : null;
    this.pinnedFeeRate =
        (pinnedFeeRate != null && pinnedFeeRate >= 0 && pinnedFeeRate.isFinite)
            ? pinnedFeeRate
            : null;
    this.pinnedFiatCode =
        (pinnedFiatCode != null && pinnedFiatCode.isNotEmpty)
            ? pinnedFiatCode
            : null;
    this.pinnedFiatAmount =
        (pinnedFiatAmount != null && pinnedFiatAmount > 0)
            ? pinnedFiatAmount
            : null;
    this.pinnedPremium =
        (pinnedPremium != null && pinnedPremium.isFinite) ? pinnedPremium : null;

    _peer = peer;
    if (peer != null) {
      _sharedKey = NostrUtils.computeSharedKey(
        tradeKey.private,
        peer.publicKey,
      );
    }
    if (adminPubkey != null) {
      setAdminPeer(adminPubkey);
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
        'dispute_id': disputeId,
        'pinned_amount_sats': pinnedAmountSats,
        'pinned_fee_rate': pinnedFeeRate,
        'pinned_fiat_code': pinnedFiatCode,
        'pinned_fiat_amount': pinnedFiatAmount,
        'pinned_premium': pinnedPremium,
        'terms_pinned': termsPinned,
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

      // Parse optional admin pubkey
      String? adminPubkey;
      final adminPeerValue = json['admin_peer'];
      if (adminPeerValue != null) {
        if (adminPeerValue is String && adminPeerValue.isNotEmpty) {
          adminPubkey = adminPeerValue;
        } else if (adminPeerValue is! String) {
          throw FormatException(
            'Invalid admin_peer type: ${adminPeerValue.runtimeType}',
          );
        }
      }

      // Parse optional dispute ID
      String? disputeId;
      final disputeIdValue = json['dispute_id'];
      if (disputeIdValue != null && disputeIdValue is String && disputeIdValue.isNotEmpty) {
        disputeId = disputeIdValue;
      }

      // Absent in sessions written before the terms were pinned, so a missing
      // or unusable value reads as "nothing was pinned" rather than an error:
      // those trades fall back to the live events, as they always did.
      final pinnedAmountValue = json['pinned_amount_sats'];
      int? pinnedAmountSats;
      if (pinnedAmountValue is int) {
        pinnedAmountSats = pinnedAmountValue;
      } else if (pinnedAmountValue is String) {
        pinnedAmountSats = int.tryParse(pinnedAmountValue);
      }

      final termsPinnedValue = json['terms_pinned'];
      final termsPinned = termsPinnedValue is bool
          ? termsPinnedValue
          : termsPinnedValue is String
              ? termsPinnedValue.toLowerCase() == 'true'
              : false;

      final pinnedFeeValue = json['pinned_fee_rate'];
      double? pinnedFeeRate;
      if (pinnedFeeValue is num) {
        pinnedFeeRate = pinnedFeeValue.toDouble();
      } else if (pinnedFeeValue is String) {
        pinnedFeeRate = double.tryParse(pinnedFeeValue);
      }

      final pinnedFiatAmountValue = json['pinned_fiat_amount'];
      int? pinnedFiatAmount;
      if (pinnedFiatAmountValue is int) {
        pinnedFiatAmount = pinnedFiatAmountValue;
      } else if (pinnedFiatAmountValue is String) {
        pinnedFiatAmount = int.tryParse(pinnedFiatAmountValue);
      }

      final pinnedPremiumValue = json['pinned_premium'];
      double? pinnedPremium;
      if (pinnedPremiumValue is num) {
        pinnedPremium = pinnedPremiumValue.toDouble();
      } else if (pinnedPremiumValue is String) {
        pinnedPremium = double.tryParse(pinnedPremiumValue);
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
        adminPubkey: adminPubkey,
        disputeId: disputeId,
        pinnedAmountSats: pinnedAmountSats,
        pinnedFeeRate: pinnedFeeRate,
        pinnedFiatCode: json['pinned_fiat_code']?.toString(),
        pinnedFiatAmount: pinnedFiatAmount,
        pinnedPremium: pinnedPremium,
        termsPinned: termsPinned,
      );
    } catch (e) {
      throw FormatException('Failed to parse Session from JSON: $e');
    }
  }

  NostrKeyPairs? get sharedKey => _sharedKey;

  String? get adminPubkey => _adminPubkey;
  NostrKeyPairs? get adminSharedKey => _adminSharedKey;

  /// Inner event signers accepted in the dispute chat conversation.
  /// adminPubkey is always set when adminSharedKey is (see setAdminPeer).
  List<String> get disputeChatAllowedSigners => [
        tradeKey.public,
        if (_adminPubkey != null) _adminPubkey!,
      ];

  /// Inner event signers accepted in the peer chat conversation.
  /// The peer is always set when sharedKey is (see the peer setter).
  List<String> get peerChatAllowedSigners => [
        tradeKey.public,
        if (_peer != null) _peer!.publicKey,
      ];

  /// Compute and store the admin shared key via ECDH
  void setAdminPeer(String adminPubkey) {
    if (adminPubkey.isEmpty || adminPubkey.length != 64) {
      throw ArgumentError(
        'Invalid admin pubkey: expected 64-char hex, got ${adminPubkey.length} chars',
      );
    }
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
