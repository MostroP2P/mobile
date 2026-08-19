import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// The kind the orders subscription would listen on for [version].
int _listeningKind(int? version) {
  final filter = buildOrdersFilter(
    resolveTransport(version),
    ['a' * 64],
    'b' * 64,
  );
  return filter.kinds!.single;
}

/// The kind an outbound message would actually be published as for [version].
Future<int> _publishingKind(int? version) async {
  final tradeKey = NostrUtils.generateKeyPair();
  final message = MostroMessage(action: Action.fiatSent, id: 'order-1');

  final event = await message.wrapForTransport(
    protocolVersion: version,
    tradeKey: tradeKey,
    recipientPubKey: NostrUtils.generateKeyPair().public,
  );
  return event.kind!;
}

void main() {
  // Send and receive derive their kind from the same resolution. If they ever
  // disagree the client is partitioned from the node — listening on one kind
  // while publishing on another — and the half an attacker controls is the
  // forgeable one. These lock the two together at the only values that reach
  // the wire.
  group('send and receive resolve to the same kind', () {
    for (final version in <int?>[null, 1, 2, 3, 99]) {
      test('protocol_version $version', () async {
        expect(await _publishingKind(version), _listeningKind(version));
      });
    }
  });

  group('resolved kinds are the protocol kinds', () {
    test('v1 is gift wrap (1059)', () async {
      expect(_listeningKind(1), 1059);
      expect(await _publishingKind(1), 1059);
    });

    test('v2 is NIP-44 direct (14)', () async {
      expect(_listeningKind(2), 14);
      expect(await _publishingKind(2), 14);
    });

    // An unknown node must not land on the forgeable transport, on either
    // side of the connection.
    test('an unknown node lands on kind 14, not 1059', () async {
      expect(_listeningKind(null), 14);
      expect(await _publishingKind(null), 14);
    });
  });
}
