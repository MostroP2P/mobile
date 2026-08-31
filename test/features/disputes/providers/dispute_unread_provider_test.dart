import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_read_status_provider.dart';
import 'package:mostro_mobile/services/dispute_read_status_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dispute unread dot was a `FutureBuilder` whose future (a prefs read)
/// was recreated on every rebuild. It is now [disputeHasUnreadProvider],
/// which caches its value and recomputes on [disputeReadStatusProvider]
/// bumps — the bump after `markDisputeAsRead` replaces the FutureBuilder's
/// per-rebuild self-healing, so it must observe the fresh cursor.
void main() {
  const disputeId = 'dispute-a';
  const userPubkey = 'user-pubkey';
  const adminPubkey = 'admin-pubkey';

  late ProviderContainer container;
  late List<DisputeChatMessage> messages;

  DisputeChatMessage message(String id, String pubkey, int createdAt) =>
      DisputeChatMessage(
        event: NostrEvent(
          id: id,
          kind: 14,
          content: 'hola',
          sig: '',
          pubkey: pubkey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
          tags: const [],
        ),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messages = [];
    container = ProviderContainer(overrides: [
      disputeChatNotifierProvider.overrideWith(
        (ref, id) => _FakeDisputeChatNotifier(id, ref, messages),
      ),
    ]);
  });

  tearDown(() => container.dispose());

  test('an admin message with no read cursor is unread', () async {
    messages = [message('m1', adminPubkey, 1000)];

    final unread =
        await container.read(disputeHasUnreadProvider(disputeId).future);

    expect(unread, isTrue);
  });

  test('own messages never count as unread', () async {
    messages = [message('m1', userPubkey, 1000)];

    final unread =
        await container.read(disputeHasUnreadProvider(disputeId).future);

    expect(unread, isFalse);
  });

  test('the read-status bump recomputes against the fresh cursor', () async {
    messages = [message('m1', adminPubkey, 1000)];

    final before =
        await container.read(disputeHasUnreadProvider(disputeId).future);
    expect(before, isTrue);

    // What DisputeChatScreen does on open: persist the cursor, then bump.
    await DisputeReadStatusService.markDisputeAsRead(disputeId);
    container.read(disputeReadStatusProvider(disputeId).notifier).state =
        DateTime.now().millisecondsSinceEpoch;

    final after =
        await container.read(disputeHasUnreadProvider(disputeId).future);
    expect(after, isFalse);
  });

  test('an empty dispute chat has nothing unread', () async {
    final unread =
        await container.read(disputeHasUnreadProvider(disputeId).future);

    expect(unread, isFalse);
  });
}

/// Dispute chat state the provider can read without touching Nostr or
/// storage. [isFromUser] is overridden because the real implementation walks
/// sessions and order state to find the trade key.
class _FakeDisputeChatNotifier extends DisputeChatNotifier {
  _FakeDisputeChatNotifier(
    super.disputeId,
    super.ref,
    List<DisputeChatMessage> messages,
  ) {
    state = DisputeChatState(messages: messages);
  }

  @override
  bool isFromUser(DisputeChatMessage message) =>
      message.event.pubkey == 'user-pubkey';
}
