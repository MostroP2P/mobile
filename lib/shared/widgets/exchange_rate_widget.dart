import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';

class ExchangeRateWidget extends ConsumerWidget {
  final String currency;

  const ExchangeRateWidget({
    super.key,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider for the specific currency
    final exchangeRateAsyncValue = ref.watch(exchangeRateProvider(currency));

    return exchangeRateAsyncValue.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (exchangeRate) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF303544),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 BTC = ${NumberFormat.currency(
                  symbol: '',
                  decimalDigits: 2,
                ).format(exchangeRate)} $currency',
                style: const TextStyle(color: Colors.white),
              ),
              Row(
                children: [
                  Text('price in $currency',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      // Trigger refresh for this specific currency
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing exchange rate...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      ref
                          .read(exchangeRateProvider(currency).notifier)
                          .fetchExchangeRate(currency);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: .3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
