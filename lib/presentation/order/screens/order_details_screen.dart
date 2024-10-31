import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
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

  final _satsAmountController = TextEditingController();

  OrderDetailsScreen({super.key, required this.initialOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostroService = ref.watch(mostroServiceProvider);
    return BlocProvider(
      create: (context) =>
          OrderDetailsBloc(mostroService)..add(LoadOrderDetails(initialOrder)),
      child: BlocBuilder<OrderDetailsBloc, OrderDetailsState>(
        builder: (context, state) {
          if (state.status == OrderDetailsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == OrderDetailsStatus.error) {
            return Center(
                child: Text(state.errorMessage ?? 'An error occurred'));
          } else if (state.status == OrderDetailsStatus.loaded) {
            return _buildContent(context, ref, state.order!);
          } else if (state.status == OrderDetailsStatus.cancelled ||
              state.status == OrderDetailsStatus.done) {
            return _buildCompletionMessage(context, state);
          }
          return const Center(child: Text('Order not found'));
        },
      ),
    );
  }

  Widget _buildCompletionMessage(
      BuildContext context, OrderDetailsState state) {
    final message = state.status == OrderDetailsStatus.cancelled
        ? 'Order has been cancelled.'
        : 'Order has been completed!';
    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for using our service!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CC541),
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
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${order.orderType?.toUpperCase()} BITCOIN',
            style: TextStyle(
                color: Colors.white,
                fontFamily: GoogleFonts.robotoCondensed().fontFamily)),
      ),
      body: BlocConsumer<OrderDetailsBloc, OrderDetailsState>(
          listener: (context, state) {
        if (state.status == OrderDetailsStatus.cancelled ||
            state.status == OrderDetailsStatus.done) {
          Navigator.of(context).pop();
        }
      }, builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSellerInfo(NostrEvent order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey,
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
                Text('${order.rating}/5 (_)',
                    style: const TextStyle(color: Color(0xFF8CC541))),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Implementar lógica para leer reseñas
            },
            child: const Text('Read reviews',
                style: TextStyle(color: Color(0xFF8CC541))),
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
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF303544),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.fiatAmount} ${order.currency} (${order.premium}%)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('${order.amount} sats',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const HeroIcon(HeroIcons.creditCard,
                      style: HeroIconStyle.outline,
                      color: Colors.white,
                      size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      order.paymentMethods[0],
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.visible,
                      softWrap: true,
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

  Widget _buildBuyerInfo(NostrEvent order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey,
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
                Text('0/5 (0)', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: Color(0xFF8CC541)),
        ],
      ),
    );
  }

  Widget _buildBuyerAmount(NostrEvent order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyTextField(controller: _satsAmountController, label: 'sats'),
          const SizedBox(height: 8),
          Text('\$ ${order.amount}',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const Row(
            children: [
              HeroIcon(HeroIcons.bolt,
                  style: HeroIconStyle.solid, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Bitcoin Lightning Network',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
              backgroundColor: const Color(0xFF8CC541),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('CONTINUE'),
          ),
        ),
      ],
    );
  }
}
