import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/chat/providers/active_chat_screens_provider.dart';

void main() {
  group('ActiveChatScreensNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('starts empty', () {
      expect(container.read(activeChatScreensProvider), isEmpty);
    });

    test('register adds id to the set and isActive returns true', () {
      final notifier = container.read(activeChatScreensProvider.notifier);

      notifier.register('order-1');

      expect(container.read(activeChatScreensProvider), contains('order-1'));
      expect(notifier.isActive('order-1'), isTrue);
      expect(notifier.isActive('order-2'), isFalse);
    });

    test('register is idempotent', () {
      final notifier = container.read(activeChatScreensProvider.notifier);

      notifier.register('order-1');
      final first = container.read(activeChatScreensProvider);
      notifier.register('order-1');
      final second = container.read(activeChatScreensProvider);

      expect(second, equals(first));
      expect(second.length, 1);
    });

    test('unregister removes the id', () {
      final notifier = container.read(activeChatScreensProvider.notifier);

      notifier.register('order-1');
      notifier.register('order-2');
      notifier.unregister('order-1');

      final state = container.read(activeChatScreensProvider);
      expect(state, isNot(contains('order-1')));
      expect(state, contains('order-2'));
    });

    test('unregister of unknown id is a no-op', () {
      final notifier = container.read(activeChatScreensProvider.notifier);

      notifier.register('order-1');
      notifier.unregister('order-unknown');

      final state = container.read(activeChatScreensProvider);
      expect(state, contains('order-1'));
      expect(state.length, 1);
    });

    test('orderIds and disputeIds can coexist without conflict', () {
      final notifier = container.read(activeChatScreensProvider.notifier);

      notifier.register('order-123');
      notifier.register('dispute-abc');

      expect(notifier.isActive('order-123'), isTrue);
      expect(notifier.isActive('dispute-abc'), isTrue);

      notifier.unregister('order-123');

      expect(notifier.isActive('order-123'), isFalse);
      expect(notifier.isActive('dispute-abc'), isTrue);
    });
  });
}
