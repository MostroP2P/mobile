import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

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
            color: AppTheme.dark2,
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
                style: const TextStyle(color: AppTheme.cream1),
              ),
              Row(
                children: [
                  Text('price in $currency',
                      style: const TextStyle(color: AppTheme.grey)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      // Trigger refresh for this specific currency
                      SnackBarHelper.showTopSnackBar(
                        context,
                        'Refreshing exchange rate...',
                        duration: const Duration(seconds: 1),
                      );
                      ref
                          .read(exchangeRateProvider(currency).notifier)
                          .fetchExchangeRate(currency);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.grey.withValues(alpha: .3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: AppTheme.cream1,
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
