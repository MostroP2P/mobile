import 'package:flutter_test/flutter_test.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  // Use valid keys from NIP-06 test vectors
  const validMnemonic =
      'leader monkey parrot ring guide accident before fence cannon height naive bean';
  final keyDerivator = KeyDerivator(Config.keyDerivationPath);
  final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(validMnemonic);
  final masterPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
  final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 1);
  final peerPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 2);
  final peerPublicKey = keyDerivator.privateToPublicKey(peerPrivKey);
  final adminPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 3);
  final adminPublicKey = keyDerivator.privateToPublicKey(adminPrivKey);
  final tradePublicKey = keyDerivator.privateToPublicKey(tradePrivKey);

  group('Dispute Shared Key Computation', () {
    test('computes identical shared key from both sides (user and admin)', () {
      // User side: ECDH(tradeKey.private, adminPubkey)
      final userSideKey =
          NostrUtils.computeSharedKey(tradePrivKey, adminPublicKey);

      // Admin side: ECDH(adminKey.private, tradeKey.public)
      final adminSideKey =
          NostrUtils.computeSharedKey(adminPrivKey, tradePublicKey);

      // Both should produce the same shared secret
      expect(userSideKey.private, equals(adminSideKey.private));
      expect(userSideKey.public, equals(adminSideKey.public));
    });

    test('admin shared key is independent from peer shared key', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
        peer: Peer(publicKey: peerPublicKey),
      );

      // Set admin peer
      session.setAdminPeer(adminPublicKey);

      // Both keys should exist
      expect(session.sharedKey, isNotNull);
      expect(session.adminSharedKey, isNotNull);

      // Keys should be different
      expect(
          session.sharedKey!.private, isNot(equals(session.adminSharedKey!.private)));
      expect(
          session.sharedKey!.public, isNot(equals(session.adminSharedKey!.public)));
    });

    test('admin shared key is null when no admin assigned', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
      );

      expect(session.adminSharedKey, isNull);
      expect(session.adminPubkey, isNull);
    });

    test('setAdminPeer computes and stores admin shared key', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
      );

      expect(session.adminSharedKey, isNull);

      session.setAdminPeer(adminPublicKey);

      expect(session.adminSharedKey, isNotNull);
      expect(session.adminPubkey, equals(adminPublicKey));

      // Verify the computed key matches manual ECDH computation
      final expectedKey =
          NostrUtils.computeSharedKey(tradePrivKey, adminPublicKey);
      expect(session.adminSharedKey!.private, equals(expectedKey.private));
      expect(session.adminSharedKey!.public, equals(expectedKey.public));
    });

    test('constructor computes admin shared key when adminPeer is provided', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
        adminPeer: adminPublicKey,
      );

      expect(session.adminSharedKey, isNotNull);
      expect(session.adminPubkey, equals(adminPublicKey));
    });

    test('toJson includes admin_peer and fromJson restores it', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
        peer: Peer(publicKey: peerPublicKey),
        adminPeer: adminPublicKey,
      );

      final json = session.toJson();
      expect(json['admin_peer'], equals(adminPublicKey));

      // Reconstruct from JSON (fromJson needs key pair objects, not just public keys)
      // So we test the serialized value is present and correct
      final restoredSession = Session.fromJson({
        ...json,
        'master_key': NostrKeyPairs(private: masterPrivKey),
        'trade_key': NostrKeyPairs(private: tradePrivKey),
      });

      expect(restoredSession.adminPubkey, equals(adminPublicKey));
      expect(restoredSession.adminSharedKey, isNotNull);
      expect(restoredSession.adminSharedKey!.private,
          equals(session.adminSharedKey!.private));
    });

    test('session can have both peer and admin simultaneously', () {
      final session = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order',
        role: Role.buyer,
        peer: Peer(publicKey: peerPublicKey),
        adminPeer: adminPublicKey,
      );

      // Both shared keys exist
      expect(session.sharedKey, isNotNull);
      expect(session.adminSharedKey, isNotNull);
      expect(session.peer, isNotNull);
      expect(session.adminPubkey, isNotNull);

      // They are independent
      expect(session.sharedKey!.public,
          isNot(equals(session.adminSharedKey!.public)));
    });
  });
}
