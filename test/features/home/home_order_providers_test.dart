import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  int activeCount() => container.read(activeFilterCountProvider);

  group('activeFilterCountProvider', () {
    test('is zero when no filter has been touched', () {
      expect(activeCount(), 0);
    });

    test('counts a currency selection', () {
      container.read(currencyFilterProvider.notifier).state = ['USD'];
      expect(activeCount(), 1);
    });

    test('counts a payment method selection', () {
      container.read(paymentMethodFilterProvider.notifier).state = ['Bank'];
      expect(activeCount(), 1);
    });

    test('counts a minimum days filter above the default', () {
      container.read(minDaysFilterProvider.notifier).state = 5;
      expect(activeCount(), 1);
    });

    test('does not count minimum days left at the default', () {
      container.read(minDaysFilterProvider.notifier).state = kDefaultMinDays;
      expect(activeCount(), 0);
    });

    test('counts a rating range narrowed only on the lower bound', () {
      container.read(ratingFilterProvider.notifier).state =
          (min: 3.0, max: kDefaultRatingMax);
      expect(activeCount(), 1);
    });

    test('counts a rating range narrowed only on the upper bound', () {
      container.read(ratingFilterProvider.notifier).state =
          (min: kDefaultRatingMin, max: 4.0);
      expect(activeCount(), 1);
    });

    test('stops counting a rating range restored to its defaults', () {
      final notifier = container.read(ratingFilterProvider.notifier);
      notifier.state = (min: 3.0, max: 4.0);
      expect(activeCount(), 1);

      notifier.state = (min: kDefaultRatingMin, max: kDefaultRatingMax);
      expect(activeCount(), 0);
    });

    test('counts a premium range narrowed only on the lower bound', () {
      container.read(premiumRangeFilterProvider.notifier).state =
          (min: -5.0, max: kDefaultPremiumMax);
      expect(activeCount(), 1);
    });

    test('counts a premium range narrowed only on the upper bound', () {
      container.read(premiumRangeFilterProvider.notifier).state =
          (min: kDefaultPremiumMin, max: 5.0);
      expect(activeCount(), 1);
    });

    test('stops counting a premium range restored to its defaults', () {
      final notifier = container.read(premiumRangeFilterProvider.notifier);
      notifier.state = (min: -5.0, max: 5.0);
      expect(activeCount(), 1);

      notifier.state = (min: kDefaultPremiumMin, max: kDefaultPremiumMax);
      expect(activeCount(), 0);
    });

    test('adds up every active filter', () {
      container.read(currencyFilterProvider.notifier).state = ['USD', 'EUR'];
      container.read(paymentMethodFilterProvider.notifier).state = ['Bank'];
      container.read(minDaysFilterProvider.notifier).state = 10;
      container.read(ratingFilterProvider.notifier).state = (min: 3.0, max: 5.0);
      container.read(premiumRangeFilterProvider.notifier).state =
          (min: -2.0, max: 2.0);

      expect(activeCount(), 5);
    });
  });

  group('clearAllOrderFilters', () {
    test('restores every filter to its default value', () {
      container.read(currencyFilterProvider.notifier).state = ['USD'];
      container.read(paymentMethodFilterProvider.notifier).state = ['Bank'];
      container.read(minDaysFilterProvider.notifier).state = 10;
      container.read(ratingFilterProvider.notifier).state = (min: 3.0, max: 4.0);
      container.read(premiumRangeFilterProvider.notifier).state =
          (min: -2.0, max: 2.0);
      expect(activeCount(), 5);

      clearAllOrderFilters(container.read);

      expect(activeCount(), 0);
      expect(container.read(currencyFilterProvider), isEmpty);
      expect(container.read(paymentMethodFilterProvider), isEmpty);
      expect(container.read(minDaysFilterProvider), kDefaultMinDays);
      expect(container.read(ratingFilterProvider),
          (min: kDefaultRatingMin, max: kDefaultRatingMax));
      expect(container.read(premiumRangeFilterProvider),
          (min: kDefaultPremiumMin, max: kDefaultPremiumMax));
    });

    test('is a no-op when no filter is active', () {
      clearAllOrderFilters(container.read);
      expect(activeCount(), 0);
    });
  });
}
