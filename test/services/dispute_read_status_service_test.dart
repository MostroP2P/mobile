import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/services/dispute_read_status_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A preferences store whose every operation fails, standing in for a
/// platform-channel error, a full disk or corrupted preferences.
class _ThrowingStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => throw StateError('preferences unavailable');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw StateError('preferences unavailable');

  @override
  Future<bool> remove(String key) async =>
      throw StateError('preferences unavailable');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw StateError('preferences unavailable');
}

DisputeChatMessage message({required bool fromUser}) => DisputeChatMessage(
      event: NostrEvent(
        id: fromUser ? 'mine' : 'theirs',
        kind: 14,
        pubkey: fromUser ? 'me' : 'them',
        content: 'hello',
        createdAt: DateTime.utc(2026, 1, 2),
        tags: const [],
        sig: '',
      ),
    );

bool isFromUser(DisputeChatMessage m) => m.event.pubkey == 'me';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisputeReadStatusService with working storage', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('records and reads back the last read time', () async {
      expect(await DisputeReadStatusService.getLastReadTime('d1'), isNull);

      await DisputeReadStatusService.markDisputeAsRead('d1');

      expect(await DisputeReadStatusService.getLastReadTime('d1'), isNotNull);
    });

    test('messages older than the last read time are not unread', () async {
      await DisputeReadStatusService.markDisputeAsRead('d1');

      expect(
        await DisputeReadStatusService.hasUnreadMessages(
          'd1',
          [message(fromUser: false)],
          isFromUser: isFromUser,
        ),
        isFalse,
      );
    });
  });

  group('DisputeReadStatusService degrades when storage is unavailable', () {
    setUp(() {
      SharedPreferencesStorePlatform.instance = _ThrowingStore();
      SharedPreferences.resetStatic();
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('markDisputeAsRead completes instead of throwing', () async {
      await expectLater(
        DisputeReadStatusService.markDisputeAsRead('d1'),
        completes,
      );
    });

    test('getLastReadTime reports nothing read yet', () async {
      expect(await DisputeReadStatusService.getLastReadTime('d1'), isNull);
    });

    test('hasUnreadMessages treats incoming messages as unread', () async {
      expect(
        await DisputeReadStatusService.hasUnreadMessages(
          'd1',
          [message(fromUser: false)],
          isFromUser: isFromUser,
        ),
        isTrue,
      );
    });

    test('hasUnreadMessages ignores the user own messages', () async {
      expect(
        await DisputeReadStatusService.hasUnreadMessages(
          'd1',
          [message(fromUser: true)],
          isFromUser: isFromUser,
        ),
        isFalse,
      );
    });
  });
}
