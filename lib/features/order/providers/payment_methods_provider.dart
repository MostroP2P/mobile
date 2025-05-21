import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Proveedor para cargar los métodos de pago desde el archivo JSON
final paymentMethodsDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final String response = await rootBundle.loadString('assets/data/payment_methods.json');
  return jsonDecode(response) as Map<String, dynamic>;
});

// Proveedor para obtener los métodos de pago basados en la moneda seleccionada
final paymentMethodsForCurrencyProvider = Provider.family<List<String>, String>((ref, currencyCode) {
  final paymentMethodsData = ref.watch(paymentMethodsDataProvider);
  
  return paymentMethodsData.when(
    data: (data) {
      // Obtener los métodos de pago para la moneda específica o usar los valores por defecto
      if (data.containsKey(currencyCode)) {
        final methods = List<String>.from(data[currencyCode]);
        // Asegurarse de que 'Other' siempre esté incluido
        if (!methods.contains('Other')) {
          methods.add('Other');
        }
        return methods;
      } else {
        // Usar los valores por defecto
        return List<String>.from(data['default'] ?? ['Bank Transfer', 'Cash in person', 'Other']);
      }
    },
    loading: () => ['Loading...'],
    error: (_, __) => ['Bank Transfer', 'Cash in person', 'Other'],
  );
});

// Provider para los métodos de pago seleccionados
final selectedPaymentMethodsProvider = StateProvider<List<String>>((ref) => []);

// Provider para el método de pago personalizado
final customPaymentMethodProvider = StateProvider<String?>((ref) => null);
