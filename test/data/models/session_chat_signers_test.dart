import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';

/// The chat allow-lists gate which inner-event signers a conversation
/// accepts (chatUnwrap step 9). These pure tests lock their contents in.
void main() {
  final tradeKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final peerKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000002',
  );
  final adminKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000003',
  );

  Session makeSession() => Session(
        masterKey: tradeKey,
        tradeKey: tradeKey,
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.parse('2026-08-18T12:00:00.000'),
        orderId: 'order-1',
      );

  group('Session.peerChatAllowedSigners', () {
    test('contains only the own trade key while no peer is set', () {
      expect(makeSession().peerChatAllowedSigners, equals([tradeKey.public]));
    });

    test('contains both trade keys once the peer is set', () {
      final session = makeSession()..peer = Peer(publicKey: peerKey.public);

      expect(
        session.peerChatAllowedSigners,
        equals([tradeKey.public, peerKey.public]),
      );
      // Setting the peer also derives the conversation's ECDH shared key
      expect(session.sharedKey, isNotNull);
    });
  });

  group('Session.disputeChatAllowedSigners', () {
    test('contains both parties once the admin peer is set', () {
      final session = makeSession()..setAdminPeer(adminKey.public);

      expect(
        session.disputeChatAllowedSigners,
        equals([tradeKey.public, adminKey.public]),
      );
      expect(session.adminSharedKey, isNotNull);
    });
  });
}
