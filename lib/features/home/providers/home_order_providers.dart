import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

final homeOrderTypeProvider = StateProvider((ref) => OrderType.sell);

// Default values for the order book filters. A filter is considered active
// only when its state differs from these defaults.
const double kDefaultRatingMin = 0.0;
const double kDefaultRatingMax = 5.0;
const double kDefaultPremiumMin = -10.0;
const double kDefaultPremiumMax = 10.0;
const int kDefaultMinDays = 0;

// Filter state providers
final currencyFilterProvider = StateProvider<List<String>>((ref) => []);
final paymentMethodFilterProvider = StateProvider<List<String>>((ref) => []);
final ratingFilterProvider = StateProvider<({double min, double max})>(
    (ref) => (min: kDefaultRatingMin, max: kDefaultRatingMax));
final premiumRangeFilterProvider = StateProvider<({double min, double max})>(
    (ref) => (min: kDefaultPremiumMin, max: kDefaultPremiumMax));
final minDaysFilterProvider = StateProvider<int>((ref) => kDefaultMinDays);

/// Single definition of "this filter is active", so the count shown in the UI
/// can never disagree with the filtering actually applied.
bool _isMinDaysActive(int minDays) => minDays > kDefaultMinDays;

bool _isRatingActive(({double min, double max}) range) =>
    range.min > kDefaultRatingMin || range.max < kDefaultRatingMax;

bool _isPremiumActive(({double min, double max}) range) =>
    range.min > kDefaultPremiumMin || range.max < kDefaultPremiumMax;

/// Number of filters that currently differ from their default value.
final activeFilterCountProvider = Provider<int>((ref) {
  final selectedCurrencies = ref.watch(currencyFilterProvider);
  final selectedPaymentMethods = ref.watch(paymentMethodFilterProvider);
  final ratingRange = ref.watch(ratingFilterProvider);
  final premiumRange = ref.watch(premiumRangeFilterProvider);
  final minDays = ref.watch(minDaysFilterProvider);

  var count = 0;
  if (selectedCurrencies.isNotEmpty) count++;
  if (selectedPaymentMethods.isNotEmpty) count++;
  if (_isMinDaysActive(minDays)) count++;
  if (_isRatingActive(ratingRange)) count++;
  if (_isPremiumActive(premiumRange)) count++;
  return count;
});

/// Signature shared by `WidgetRef.read` and `ProviderContainer.read`, so
/// [clearAllOrderFilters] can be called from widgets and from tests alike.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Resets every order book filter to its default value.
void clearAllOrderFilters(ProviderReader read) {
  read(currencyFilterProvider.notifier).state = [];
  read(paymentMethodFilterProvider.notifier).state = [];
  read(ratingFilterProvider.notifier).state =
      (min: kDefaultRatingMin, max: kDefaultRatingMax);
  read(premiumRangeFilterProvider.notifier).state =
      (min: kDefaultPremiumMin, max: kDefaultPremiumMax);
  read(minDaysFilterProvider.notifier).state = kDefaultMinDays;
}

final filteredOrdersProvider = Provider<List<NostrEvent>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final orderType = ref.watch(homeOrderTypeProvider);
  final selectedCurrencies = ref.watch(currencyFilterProvider);
  final selectedPaymentMethods = ref.watch(paymentMethodFilterProvider);
  final ratingRange = ref.watch(ratingFilterProvider);
  final premiumRange = ref.watch(premiumRangeFilterProvider);
  final minDays = ref.watch(minDaysFilterProvider);

  return allOrdersAsync.maybeWhen(
    data: (allOrders) {
      allOrders
          .sort((o1, o2) => o1.expirationDate.compareTo(o2.expirationDate));

      var filtered = allOrders.reversed
          .where((o) => o.orderType == orderType)
          .where((o) => o.status == Status.pending);

      // Apply currency filter
      if (selectedCurrencies.isNotEmpty) {
        filtered = filtered.where((o) => 
          o.currency != null && selectedCurrencies.contains(o.currency!)
        );
      }

      // Apply payment method filter
      if (selectedPaymentMethods.isNotEmpty) {
        final methodsLower = selectedPaymentMethods
            .where((m) => m.trim().isNotEmpty)
            .map((m) => m.toLowerCase())
            .toSet();
        filtered = filtered.where((o) {
          final pms = o.paymentMethods;
          if (pms.isEmpty) return false;
          return pms.any((pm) {
            final pmLower = pm.toLowerCase();
            return methodsLower.any(pmLower.contains);
          });
        });
      }

      // Apply minimum days filter (maker's account age as reported in rating.days)
      if (_isMinDaysActive(minDays)) {
        filtered = filtered.where((o) => (o.rating?.days ?? 0) >= minDays);
      }

      // Apply rating filter
      if (_isRatingActive(ratingRange)) {
        filtered = filtered.where((o) => 
          o.rating != null && 
          o.rating!.totalRating >= ratingRange.min &&
          o.rating!.totalRating <= ratingRange.max
        );
      }

      // Apply premium/discount filter
      if (_isPremiumActive(premiumRange)) {
        filtered = filtered.where((o) {
          if (o.premium == null || o.premium!.isEmpty) return false;
          final premiumValue = double.tryParse(o.premium!) ?? 0.0;
          return premiumValue >= premiumRange.min && premiumValue <= premiumRange.max;
        });
      }

      return filtered.toList();
    },
    orElse: () => [],
  );
});
