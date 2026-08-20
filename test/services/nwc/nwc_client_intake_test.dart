import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nwc/nwc_client.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_crypto.dart';
import 'package:mostro_mobile/services/nwc/nwc_models.dart';
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
  late NostrKeyPairs clientKeys;
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
    clientKeys = NostrUtils.generateKeyPair();
    client = NwcClient(
      connection: NwcConnection(
        walletPubkey: walletKeys.public,
        relayUrls: const ['wss://wallet.relay.example'],
        secret: clientKeys.private,
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

  group('NwcClient.handleResponseEvent', () {
    const requestId = 'aaaabbbbccccddddeeeeffff00001111';

    /// A response the wallet really sent: NIP-44 to the client's key, signed
    /// by the wallet, tagged with the request it answers.
    Future<NostrEvent> genuineResponse({
      String resultType = 'pay_invoice',
      Map<String, dynamic> result = const {'preimage': 'deadbeef'},
      String eTag = requestId,
    }) async {
      final payload = jsonEncode({
        'result_type': resultType,
        'result': result,
      });
      final encrypted = await NwcCrypto.encrypt(
        payload,
        walletKeys.private,
        clientKeys.public,
        NwcEncryption.nip44,
      );
      return NostrEvent.fromPartialData(
        kind: 23195,
        content: encrypted,
        keyPairs: walletKeys,
        tags: [
          ['e', eTag],
          ['p', clientKeys.public],
        ],
      );
    }

    test('completes the request with a genuine wallet response', () async {
      final completer = Completer<NwcResponse>();

      await client.handleResponseEvent(
          await genuineResponse(), requestId, completer);

      expect(completer.isCompleted, isTrue);
      final response = await completer.future;
      expect(response.isSuccess, isTrue);
      expect(response.result!['preimage'], 'deadbeef');
    });

    // The core of the finding. The request id travels in the clear on the
    // relay carrying it, so anything reaching this stream can address a reply
    // to this request. Failing here reported "payment failed" before the
    // wallet's real response arrived, and the retry is what costs money.
    test('an undecryptable event does not fail the request', () async {
      final completer = Completer<NwcResponse>();
      final garbage = NostrEvent.fromPartialData(
        kind: 23195,
        content: 'not-ciphertext',
        keyPairs: walletKeys,
        tags: const [
          ['e', requestId],
        ],
      );

      await client.handleResponseEvent(garbage, requestId, completer);

      expect(completer.isCompleted, isFalse);
    });

    test('the genuine response still lands after an injected one', () async {
      final completer = Completer<NwcResponse>();
      final garbage = NostrEvent.fromPartialData(
        kind: 23195,
        content: 'not-ciphertext',
        keyPairs: walletKeys,
        tags: const [
          ['e', requestId],
        ],
      );

      await client.handleResponseEvent(garbage, requestId, completer);
      await client.handleResponseEvent(
          await genuineResponse(), requestId, completer);

      expect(completer.isCompleted, isTrue);
      expect((await completer.future).result!['preimage'], 'deadbeef');
    });

    test('a forged event claiming the wallet key does not fail the request',
        () async {
      final completer = Completer<NwcResponse>();
      final forged = NostrEvent(
        id: 'a' * 64,
        sig: 'b' * 128,
        pubkey: walletKeys.public,
        kind: 23195,
        content: 'garbage',
        createdAt: DateTime.now(),
        tags: const [
          ['e', requestId],
        ],
      );

      await client.handleResponseEvent(forged, requestId, completer);

      expect(completer.isCompleted, isFalse);
    });

    test('a response to a different request is ignored', () async {
      final completer = Completer<NwcResponse>();

      await client.handleResponseEvent(
        await genuineResponse(eTag: 'a-different-request'),
        requestId,
        completer,
      );

      expect(completer.isCompleted, isFalse);
    });

    test('an event with no content is ignored', () async {
      final completer = Completer<NwcResponse>();
      final empty = NostrEvent.fromPartialData(
        kind: 23195,
        content: '',
        keyPairs: walletKeys,
        tags: const [
          ['e', requestId],
        ],
      );

      await client.handleResponseEvent(empty, requestId, completer);

      expect(completer.isCompleted, isFalse);
    });

    test('an error response from the wallet still completes the request',
        () async {
      // Only the wallet's own errors reach the caller; a relay cannot
      // manufacture one.
      final completer = Completer<NwcResponse>();
      final payload = jsonEncode({
        'result_type': 'pay_invoice',
        'error': {'code': 'INSUFFICIENT_BALANCE', 'message': 'no funds'},
      });
      final encrypted = await NwcCrypto.encrypt(
        payload,
        walletKeys.private,
        clientKeys.public,
        NwcEncryption.nip44,
      );
      final event = NostrEvent.fromPartialData(
        kind: 23195,
        content: encrypted,
        keyPairs: walletKeys,
        tags: const [
          ['e', requestId],
        ],
      );

      await client.handleResponseEvent(event, requestId, completer);

      expect(completer.isCompleted, isTrue);
      expect((await completer.future).isSuccess, isFalse);
    });
  });
}
