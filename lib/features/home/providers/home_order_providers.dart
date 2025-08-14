import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

final homeOrderTypeProvider = StateProvider((ref) => OrderType.sell);

// Filter state providers
final currencyFilterProvider = StateProvider<List<String>>((ref) => []);
final paymentMethodFilterProvider = StateProvider<List<String>>((ref) => []);
final ratingFilterProvider = StateProvider<({double min, double max})>((ref) => (min: 0.0, max: 5.0));
final premiumRangeFilterProvider = StateProvider<({double min, double max})>((ref) => (min: -10.0, max: 10.0));

final filteredOrdersProvider = Provider<List<NostrEvent>>((ref) {
  final allOrdersAsync = ref.watch(orderEventsProvider);
  final orderType = ref.watch(homeOrderTypeProvider);
  final selectedCurrencies = ref.watch(currencyFilterProvider);
  final selectedPaymentMethods = ref.watch(paymentMethodFilterProvider);
  final ratingRange = ref.watch(ratingFilterProvider);
  final premiumRange = ref.watch(premiumRangeFilterProvider);

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
        filtered = filtered.where((o) => 
          o.paymentMethods.isNotEmpty && 
          selectedPaymentMethods.any((method) => 
            o.paymentMethods.any((pm) => 
              pm.toLowerCase().contains(method.toLowerCase())
            )
          )
        );
      }

      // Apply rating filter
      if (ratingRange.min > 0.0 || ratingRange.max < 5.0) {
        filtered = filtered.where((o) => 
          o.rating != null && 
          o.rating!.totalRating >= ratingRange.min &&
          o.rating!.totalRating <= ratingRange.max
        );
      }

      // Apply premium/discount filter
      if (premiumRange.min > -10.0 || premiumRange.max < 10.0) {
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
