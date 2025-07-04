import 'package:circular_countdown/circular_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';

import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';

import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String orderId;
  final TextTheme textTheme = AppTheme.theme.textTheme;

  TradeDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeState = ref.watch(orderNotifierProvider(orderId));
    // If message is null or doesn't have an Order payload, show loading
    final orderPayload = tradeState.order;
    if (orderPayload == null) {
      return const Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'ORDER DETAILS'),
      body: Builder(
        builder: (context) {
          // Check if this is a pending order (created by user but not taken yet)
          final isPendingOrder = tradeState.status == Status.pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: isPendingOrder
                ? _buildPendingOrderLayout(
                    ref, tradeState, context, orderPayload)
                : _buildActiveOrderLayout(
                    ref, tradeState, context, orderPayload),
          );
        },
      ),
    );
  }

  /// Builds a card showing the user is "selling/buying X sats for Y fiat" etc.
  Widget _buildSellerAmount(WidgetRef ref, OrderState tradeState) {
    final session = ref.watch(sessionProvider(orderId));

    final selling = session!.role == Role.seller ? 'selling' : 'buying';
    final currencyFlag = CurrencyUtils.getFlagFromCurrency(
      tradeState.order!.fiatCode,
    );

    final amountString =
        '${tradeState.order!.fiatAmount} ${tradeState.order!.fiatCode} $currencyFlag';

    // If `orderPayload.amount` is 0, the trade is "at market price"
    final isZeroAmount = (tradeState.order!.amount == 0);
    final satText = isZeroAmount ? '' : ' ${tradeState.order!.amount}';
    final priceText = isZeroAmount ? 'at market price' : '';

    final premium = tradeState.order!.premium;
    final premiumText = premium == 0
        ? ''
        : (premium > 0)
            ? 'with a +$premium% premium'
            : 'with a $premium% discount';

    // Payment method
    final method = tradeState.order!.paymentMethod;
    final timestamp = formatDateTime(
      tradeState.order!.createdAt != null && tradeState.order!.createdAt! > 0
          ? DateTime.fromMillisecondsSinceEpoch(tradeState.order!.createdAt!)
          : DateTime.fromMillisecondsSinceEpoch(
              tradeState.order!.createdAt ?? 0,
            ),
    );
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              // Using Column with spacing = 2 isn't standard; using SizedBoxes for spacing is fine.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are $selling$satText sats for $amountString $priceText $premiumText',
                  style: AppTheme.theme.textTheme.bodyLarge,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Created on: $timestamp',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment methods: $method',
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show a card with the order ID that can be copied.
  Widget _buildOrderId(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SelectableText(
            orderId,
            style: const TextStyle(color: AppTheme.mostroGreen),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: orderId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.mostroGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Build a circular countdown to show how many hours are left until expiration.
  Widget _buildCountDownTime(int? expiresAtTimestamp) {
    // Convert timestamp to DateTime
    final expiration = expiresAtTimestamp != null && expiresAtTimestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtTimestamp)
        : DateTime.now().add(const Duration(hours: 24));

    // If expiration has passed, the difference is negative => zero.
    final now = DateTime.now();
    final Duration difference =
        expiration.isAfter(now) ? expiration.difference(now) : const Duration();

    // Display hours left
    final hoursLeft = difference.inHours.clamp(0, 9999);
    return Column(
      children: [
        CircularCountdown(
          countdownTotal: 24,
          countdownRemaining: hoursLeft,
        ),
        const SizedBox(height: 16),
        Text('Time Left: ${difference.toString().split('.').first}'),
      ],
    );
  }

  /// Main action button area, switching on `orderPayload.status`.

  /// Format the date time to a user-friendly string with UTC offset
  String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  /// Builds the layout for pending orders (simple layout like screenshot 2)
  Widget _buildPendingOrderLayout(WidgetRef ref, OrderState tradeState,
      BuildContext context, Order orderPayload) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Information message
        _buildPendingOrderInfo(),
        const SizedBox(height: 16),
        // Basic order info ("Someone is Selling Sats")
        _buildSellerAmount(ref, tradeState),
        const SizedBox(height: 16),
        // Payment method card
        _buildPaymentMethod(tradeState),
        const SizedBox(height: 16),
        // Created on card
        _buildCreatedOn(tradeState),
        const SizedBox(height: 16),
        // Order ID
        _buildOrderId(context),
        const SizedBox(height: 16),
        // Creator reputation
        _buildCreatorReputation(tradeState),
        const SizedBox(height: 16),
        // Time remaining
        _buildCountDownTime(orderPayload.expiresAt),
        const SizedBox(height: 36),
        // CLOSE and CANCEL buttons
        _buildPendingOrderButtons(context, ref),
      ],
    );
  }

  /// Builds the layout for active orders (clean layout like screenshot 2)
  Widget _buildActiveOrderLayout(WidgetRef ref, OrderState tradeState,
      BuildContext context, Order orderPayload) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Display basic info about the trade:
        _buildSellerAmount(ref, tradeState),
        const SizedBox(height: 16),
        // Payment method card
        _buildPaymentMethod(tradeState),
        const SizedBox(height: 16),
        // Created on card
        _buildCreatedOn(tradeState),
        const SizedBox(height: 16),
        // Order ID
        _buildOrderId(context),
        const SizedBox(height: 16),
        // Creator reputation
        _buildCreatorReputation(tradeState),
        const SizedBox(height: 16),
        // Time remaining
        _buildCountDownTime(orderPayload.expiresAt),
        const SizedBox(height: 36),
        // Action buttons (CLOSE and main action)
        _buildOrderActionButtons(context, ref, tradeState),
      ],
    );
  }

  /// Builds the information message for pending orders (only for creators)
  Widget _buildPendingOrderInfo() {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.mostroGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your offer has been published and will be available for 24 hours. Other users can now take your order.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds payment method card
  Widget _buildPaymentMethod(OrderState tradeState) {
    final paymentMethod = tradeState.order?.paymentMethod ?? '';
    final paymentMethodsText =
        paymentMethod.isNotEmpty ? paymentMethod : 'Not specified';

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.payment,
              color: AppTheme.mostroGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paymentMethodsText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds created on date card
  Widget _buildCreatedOn(OrderState tradeState) {
    final createdAt = tradeState.order?.createdAt;
    final createdText = createdAt != null
        ? formatDateTime(DateTime.fromMillisecondsSinceEpoch(createdAt * 1000))
        : 'Unknown';

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: AppTheme.mostroGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created On',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    createdText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds creator reputation card with horizontal layout
  Widget _buildCreatorReputation(OrderState tradeState) {
    // For now, show placeholder data
    // In a real implementation, this would come from the order creator's data
    const rating = 3.1;
    const reviews = 15;
    const days = 7;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator\'s Reputation',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Rating section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: AppTheme.mostroGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reviews section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reviews.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reviews',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Days section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            days.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Days',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds buttons for pending orders (CLOSE and CANCEL)
  Widget _buildPendingOrderButtons(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
            child: const Text('CLOSE'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Handle cancel order action
              final orderNotifier =
                  ref.read(orderNotifierProvider(orderId).notifier);
              orderNotifier.cancelOrder();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('CANCEL'),
          ),
        ),
      ],
    );
  }

  /// Builds action buttons for orders from home (CLOSE and main action like SELL BITCOIN)
  Widget _buildOrderActionButtons(
      BuildContext context, WidgetRef ref, OrderState tradeState) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('CLOSE'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Navigate to take order screen or handle main action
              context.push('/take-order/$orderId');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              tradeState.order?.kind.name == 'buy'
                  ? 'SELL BITCOIN'
                  : 'BUY BITCOIN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
