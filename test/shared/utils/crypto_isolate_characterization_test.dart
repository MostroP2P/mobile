import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Characterization guard for moving the per-message crypto (Schnorr verify +
/// NIP-44 decrypt, ~15-90 ms of pure-Dart BigInt) off the main isolate.
/// The change is an execution-venue change only: these pins must hold
/// identically before and after, including error propagation across the
/// isolate boundary.
void main() {
  const nodePriv =
      '0000000000000000000000000000000000000000000000000000000000000003';
  const tradePriv =
      '0000000000000000000000000000000000000000000000000000000000000004';
  final nodeKeys = NostrKeyPairs(private: nodePriv);
  final tradeKeys = NostrKeyPairs(private: tradePriv);

  Future<NostrEvent> nodeMessage(String payload) async {
    final encrypted = await NostrUtils.encryptNIP44(
      payload,
      nodePriv,
      tradeKeys.public,
    );
    return NostrEvent.fromPartialData(
      kind: 14,
      content: encrypted,
      keyPairs: nodeKeys,
      tags: [
        ['p', tradeKeys.public],
      ],
    );
  }

  test('a signed node message decrypts to its payload', () async {
    final event = await nodeMessage('{"order":{"action":"ping"}}');

    final content = await NostrUtils.decryptNIP44DirectEvent(
      event,
      tradePriv,
      expectedAuthor: nodeKeys.public,
    );

    expect(content, '{"order":{"action":"ping"}}');
  });

  test('an unexpected author is rejected', () async {
    final event = await nodeMessage('x');

    await expectLater(
      NostrUtils.decryptNIP44DirectEvent(
        event,
        tradePriv,
        expectedAuthor: tradeKeys.public,
      ),
      throwsArgumentError,
    );
  });

  test('a corrupted signature is rejected', () async {
    final event = await nodeMessage('x');
    final forged = NostrEvent(
      id: event.id,
      kind: event.kind,
      content: event.content,
      sig: tradeKeys.sign(event.id!),
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      tags: event.tags,
    );

    await expectLater(
      NostrUtils.decryptNIP44DirectEvent(
        forged,
        tradePriv,
        expectedAuthor: nodeKeys.public,
      ),
      throwsArgumentError,
    );
  });

  test('a malformed private key is rejected before any crypto', () async {
    final event = await nodeMessage('x');

    await expectLater(
      NostrUtils.decryptNIP44DirectEvent(
        event,
        'nsec-not-hex',
        expectedAuthor: nodeKeys.public,
      ),
      throwsArgumentError,
    );
  });

  test('sequential messages on one conversation decrypt correctly', () async {
    final one = await nodeMessage('uno');
    final two = await nodeMessage('dos');

    expect(
      await NostrUtils.decryptNIP44DirectEvent(one, tradePriv,
          expectedAuthor: nodeKeys.public),
      'uno',
    );
    expect(
      await NostrUtils.decryptNIP44DirectEvent(two, tradePriv,
          expectedAuthor: nodeKeys.public),
      'dos',
    );
  });
}
