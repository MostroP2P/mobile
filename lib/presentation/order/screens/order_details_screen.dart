import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/theme/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_bloc.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_state.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';
import 'package:mostro_mobile/presentation/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/providers/riverpod_providers.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final NostrEvent initialOrder;

  final TextEditingController _satsAmountController = TextEditingController();

  OrderDetailsScreen({super.key, required this.initialOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostroService = ref.watch(mostroServiceProvider);
    return BlocProvider(
      create: (context) =>
          OrderDetailsBloc(mostroService)..add(LoadOrderDetails(initialOrder)),
      child: BlocConsumer<OrderDetailsBloc, OrderDetailsState>(
        listener: (context, state) {
          if (state.status == OrderDetailsStatus.done) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case OrderDetailsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case OrderDetailsStatus.error:
              return _buildErrorScreen(state.errorMessage, context);
            case OrderDetailsStatus.cancelled:
            case OrderDetailsStatus.done:
              return _buildCompletionMessage(context, state);
            case OrderDetailsStatus.loaded:
              return _buildContent(context, ref, state.order!);
            default:
              return const Center(child: Text('Order not found'));
          }
        },
      ),
    );
  }

  Widget _buildErrorScreen(String? errorMessage, BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: _buildAppBar('Error', context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage ?? 'An unexpected error occurred.',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cream1,
                ),
                child: const Text('Return to Main Screen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionMessage(
      BuildContext context, OrderDetailsState state) {
    final message = state.status == OrderDetailsStatus.cancelled
        ? 'Order has been cancelled.'
        : state.errorMessage ??
            'Order has been completed successfully!'; // Handles custom errors or success messages
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: _buildAppBar('Completion', context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.cream1,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for using our service!',
                style: TextStyle(color: AppTheme.grey2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                ),
                child: const Text('Return to Main Screen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, NostrEvent order) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: _buildAppBar('${order.orderType?.value.toUpperCase()} BITCOIN', context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSellerInfo(order),
              const SizedBox(height: 16),
              _buildSellerAmount(order, ref),
              const SizedBox(height: 16),
              ExchangeRateWidget(currency: order.currency!),
              const SizedBox(height: 16),
              _buildBuyerInfo(order),
              const SizedBox(height: 16),
              _buildBuyerAmount(order),
              const SizedBox(height: 24),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(String title, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontFamily: GoogleFonts.robotoCondensed().fontFamily,
        ),
      ),
    );
  }

  Widget _buildSellerInfo(NostrEvent order) {
    return _infoContainer(
      Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.grey2,
            child: Text('S', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.name!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  '${order.rating?.totalRating}/${order.rating?.maxRate} (${order.rating?.totalReviews})',
                  style: const TextStyle(color: AppTheme.mostroGreen),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Implement review logic
            },
            child: const Text('Read reviews',
                style: TextStyle(color: AppTheme.mostroGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAmount(NostrEvent order, WidgetRef ref) {
    final exchangeRateAsyncValue =
        ref.watch(exchangeRateProvider(order.currency!));
    return exchangeRateAsyncValue.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (exchangeRate) {
        return _infoContainer(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.fiatAmount} ${order.currency} (${order.premium}%)',
                  style: const TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('${order.amount} sats',
                  style: const TextStyle(color: AppTheme.grey2)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuyerInfo(NostrEvent order) {
    return _infoContainer(
      const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.grey2,
            child: Text('A', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anon (you)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildBuyerAmount(NostrEvent order) {
    return _infoContainer(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyTextField(controller: _satsAmountController, label: 'Sats'),
          const SizedBox(height: 8),
          Text('\$ ${order.amount}',
              style: const TextStyle(color: AppTheme.grey2)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<OrderDetailsBloc>().add(CancelOrder());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<OrderDetailsBloc>().add(ContinueOrder(initialOrder));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
            ),
            child: const Text('CONTINUE'),
          ),
        ),
      ],
    );
  }
}
