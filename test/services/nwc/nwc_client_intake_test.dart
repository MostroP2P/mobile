import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nwc/nwc_client.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

import '../../mocks.mocks.dart';

/// Re-tags [source] while keeping its id, sig and pubkey — free for a relay,
/// and the case `isVerified()` misses because it never recomputes the id.
NostrEvent _reTagged(NostrEvent source, List<List<String>> tags) => NostrEvent(
      id: source.id,
      sig: source.sig,
      pubkey: source.pubkey,
      kind: source.kind,
      content: source.content,
      createdAt: source.createdAt,
      tags: tags,
    );

void main() {
  late NostrKeyPairs walletKeys;
  late NwcClient client;

  NostrEvent walletEvent({
    int kind = 23195,
    String content = 'ciphertext',
    List<List<String>> tags = const [],
    NostrKeyPairs? keyPair,
  }) =>
      NostrEvent.fromPartialData(
        kind: kind,
        content: content,
        keyPairs: keyPair ?? walletKeys,
        tags: tags,
      );

  setUp(() {
    walletKeys = NostrUtils.generateKeyPair();
    client = NwcClient(
      connection: NwcConnection(
        walletPubkey: walletKeys.public,
        relayUrls: const ['wss://wallet.relay.example'],
        secret: NostrUtils.generateKeyPair().private,
      ),
      nostrService: MockNostrService(),
    );
  });

  // Every NWC subscription pins kind and author in its filter, but the pinned
  // dart_nostr fork forwards relay EVENT frames without verifying them or
  // matching them against the filter. The relay on this path is the one named
  // in the user's own wallet URI.
  group('NwcClient.isFromWallet', () {
    test('accepts an event the wallet actually signed', () {
      expect(client.isFromWallet(walletEvent(), 23195), isTrue);
    });

    test('rejects an event of a different kind', () {
      expect(client.isFromWallet(walletEvent(kind: 23196), 23195), isFalse);
    });

    test('rejects an event authored by anyone else', () {
      final impostor = NostrUtils.generateKeyPair();

      expect(
        client.isFromWallet(walletEvent(keyPair: impostor), 23195),
        isFalse,
      );
    });

    test('rejects an event whose tags were rewritten under a genuine id', () {
      final genuine = walletEvent(tags: const [
        ['e', 'request-id'],
      ]);
      final tampered = _reTagged(genuine, const [
        ['e', 'a-different-request'],
      ]);

      expect(client.isFromWallet(tampered, 23195), isFalse);
    });

    test('rejects an event assembled with a placeholder signature', () {
      // The shape a relay injects: it only has to claim the wallet's pubkey
      // and name the request, both of which are public.
      final forged = NostrEvent(
        id: 'a' * 64,
        sig: 'b' * 128,
        pubkey: walletKeys.public,
        kind: 23195,
        content: 'garbage',
        createdAt: DateTime.now(),
        tags: const [
          ['e', 'request-id'],
        ],
      );

      expect(client.isFromWallet(forged, 23195), isFalse);
    });

    test('applies the same rule to the info event kind', () {
      final impostor = NostrUtils.generateKeyPair();

      expect(client.isFromWallet(walletEvent(kind: 13194), 13194), isTrue);
      expect(
        client.isFromWallet(walletEvent(kind: 13194, keyPair: impostor), 13194),
        isFalse,
      );
    });

    test('applies the same rule to the notification kind', () {
      final impostor = NostrUtils.generateKeyPair();

      expect(client.isFromWallet(walletEvent(kind: 23196), 23196), isTrue);
      expect(
        client.isFromWallet(walletEvent(kind: 23196, keyPair: impostor), 23196),
        isFalse,
      );
    });
  });
}
