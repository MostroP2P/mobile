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
            data['default'] ?? ['Bank Transfer', 'Cash in person']);
      }
    },
    loading: () => ['Loading...'],
    error: (_, __) => ['Bank Transfer', 'Cash in person'],
  );
});

/// StateNotifier to manage the selected payment methods immutably
class SelectedPaymentMethodsNotifier extends StateNotifier<List<String>> {
  SelectedPaymentMethodsNotifier() : super([]);

  /// Add a payment method to the list if it doesn't already exist
  void add(String method) {
    if (!state.contains(method)) {
      state = [...state, method];
    }
  }

  /// Remove a payment method from the list
  void remove(String method) {
    state = state.where((item) => item != method).toList();
  }

  /// Toggle a payment method (add if not present, remove if present)
  void toggle(String method) {
    if (state.contains(method)) {
      remove(method);
    } else {
      add(method);
    }
  }

  /// Set the entire list of payment methods
  void setMethods(List<String> methods) {
    state = [...methods];
  }

  /// Clear all selected payment methods
  void clear() {
    state = [];
  }
}

/// Provider for the selected payment methods
final selectedPaymentMethodsProvider =
    StateNotifierProvider<SelectedPaymentMethodsNotifier, List<String>>(
  (ref) => SelectedPaymentMethodsNotifier(),
);

/// Provider for custom payment method
class CustomPaymentMethodNotifier extends StateNotifier<String?> {
  CustomPaymentMethodNotifier() : super(null);

  void set(String? value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final customPaymentMethodProvider =
    StateNotifierProvider<CustomPaymentMethodNotifier, String?>(
  (ref) => CustomPaymentMethodNotifier(),
);
