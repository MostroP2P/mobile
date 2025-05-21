import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentMethodsDataProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final String response =
      await rootBundle.loadString('assets/data/payment_methods.json');
  return jsonDecode(response) as Map<String, dynamic>;
});

final paymentMethodsForCurrencyProvider =
    Provider.family<List<String>, String>((ref, currencyCode) {
  final paymentMethodsData = ref.watch(paymentMethodsDataProvider);

  return paymentMethodsData.when(
    data: (data) {
      if (data.containsKey(currencyCode)) {
        final methods = List<String>.from(data[currencyCode]);

        if (!methods.contains('Other')) {
          methods.add('Other');
        }
        return methods;
      } else {
        return List<String>.from(
            data['default'] ?? ['Bank Transfer', 'Cash in person', 'Other']);
      }
    },
    loading: () => ['Loading...'],
    error: (_, __) => ['Bank Transfer', 'Cash in person', 'Other'],
  );
});

final selectedPaymentMethodsProvider = StateProvider<List<String>>((ref) => []);

final customPaymentMethodProvider = StateProvider<String?>((ref) => null);
