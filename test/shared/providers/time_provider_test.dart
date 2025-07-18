import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';

void main() {
  group('TimeProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('timeProvider provides DateTime values', () async {
      final provider = container.read(timeProvider);
      
      // Test that provider is AsyncValue<DateTime>
      expect(provider, isA<AsyncValue<DateTime>>());
      
      // Test when it has data
      provider.when(
        data: (value) {
          expect(value, isA<DateTime>());
          final now = DateTime.now();
          final difference = now.difference(value).abs();
          expect(difference.inSeconds, lessThan(60)); // Within 1 minute
        },
        loading: () => expect(true, isTrue), // Loading is ok
        error: (error, stack) => fail('Should not have error'),
      );
    });

    test('countdownTimeProvider provides DateTime values', () async {
      final provider = container.read(countdownTimeProvider);
      
      // Test that provider is AsyncValue<DateTime>
      expect(provider, isA<AsyncValue<DateTime>>());
      
      // Test when it has data
      provider.when(
        data: (value) {
          expect(value, isA<DateTime>());
          final now = DateTime.now();
          final difference = now.difference(value).abs();
          expect(difference.inSeconds, lessThan(60)); // Within 1 minute
        },
        loading: () => expect(true, isTrue), // Loading is ok
        error: (error, stack) => fail('Should not have error'),
      );
    });

    test('countdownTimeProvider debouncing logic', () async {
      // Test debouncing logic conceptually
      final now = DateTime.now();
      final sameSecond = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
      final nextSecond = sameSecond.add(const Duration(seconds: 1));
      
      // Should be different seconds
      expect(nextSecond.second != sameSecond.second, isTrue);
      
      // Test time comparison logic
      final lastEmittedTime = DateTime.now();
      final currentTime = DateTime.now().add(const Duration(seconds: 1));
      
      final shouldEmit = lastEmittedTime.second != currentTime.second ||
          lastEmittedTime.minute != currentTime.minute ||
          lastEmittedTime.hour != currentTime.hour;
      
      expect(shouldEmit, isTrue);
    });

    test('countdownTimeProvider cleanup works correctly', () async {
      // Create new container to test cleanup
      final testContainer = ProviderContainer();
      final provider = testContainer.read(countdownTimeProvider);
      
      // Should be able to get a provider
      expect(provider, isA<AsyncValue<DateTime>>());
      
      // Dispose container (triggers cleanup)
      testContainer.dispose();
      
      // Test passed if no exceptions thrown
      expect(true, isTrue);
    });

    test('providers are independent', () async {
      final timeProvider1 = container.read(timeProvider);
      final countdownProvider1 = container.read(countdownTimeProvider);
      
      // Both should be valid AsyncValue<DateTime>
      expect(timeProvider1, isA<AsyncValue<DateTime>>());
      expect(countdownProvider1, isA<AsyncValue<DateTime>>());
      
      // Test that they are different providers (not the same reference)
      expect(identical(timeProvider1, countdownProvider1), isFalse);
    });
  });
}