import 'package:circular_countdown/circular_countdown.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/trades/widgets/mostro_message_detail_widget.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String orderId;
  final TextTheme textTheme = AppTheme.theme.textTheme;

  TradeDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(eventProvider(orderId));

    // Make sure we actually have an order from the provider:
    if (order == null) {
      return const Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'ORDER DETAILS'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Display basic info about the trade:
            _buildSellerAmount(ref, order),
            const SizedBox(height: 16),
            _buildOrderId(context),
            const SizedBox(height: 16),
            // Detailed info: includes the last Mostro message action text
            MostroMessageDetail(order: order),
            const SizedBox(height: 24),
            _buildCountDownTime(order.expirationDate),
            const SizedBox(height: 36),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _buildActionButtons(context, ref, order),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a card showing the user is "selling/buying X sats for Y fiat" etc.
  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order) {
    final session = ref.watch(sessionProvider(order.orderId!));

    final selling = session!.role == Role.seller ? 'selling' : 'buying';

    final amountString =
        '${order.fiatAmount} ${order.currency} ${CurrencyUtils.getFlagFromCurrency(order.currency!)}';

    // If `order.amount` is "0", the trade is "at market price"
    final isZeroAmount = (order.amount == '0');
    final satText = isZeroAmount ? '' : ' ${order.amount}';
    final priceText = isZeroAmount ? 'at market price' : '';

    final premium = int.tryParse(order.premium ?? '0') ?? 0;
    final premiumText = premium == 0
        ? ''
        : (premium > 0)
            ? 'with a +$premium% premium'
            : 'with a $premium% discount';

    // Payment method can be multiple, we only display the first for brevity:
    final method = order.paymentMethods.isNotEmpty
        ? order.paymentMethods[0]
        : 'No payment method';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              // Using Column with spacing = 2 isn’t standard; using SizedBoxes for spacing is fine.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are $selling$satText sats for $amountString $priceText $premiumText',
                  style: AppTheme.theme.textTheme.bodyLarge,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Created on: ${formatDateTime(order.createdAt!)}',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment method: $method',
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
  Widget _buildCountDownTime(DateTime expiration) {
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

  /// Main action button area, switching on `order.status`.
  /// Additional checks use `message.action` to refine which button to show.
  List<Widget> _buildActionButtons(
      BuildContext context, WidgetRef ref, NostrEvent order) {
	final message = ref.watch(orderNotifierProvider(orderId));
    final session = ref.watch(sessionProvider(orderId));

    // The finite-state-machine approach: decide based on the order.status.
    // Then refine if needed using the last action in `message.action`.
    switch (order.status) {
      case Status.pending:
        return [
          //_buildCloseButton(context),
          _buildCancelButton(context, ref),
          if (message.action == actions.Action.addInvoice)
            _buildAddInvoiceButton(context),
        ];
      case Status.waitingPayment:
        return [
          //_buildCloseButton(context),
          _buildCancelButton(context, ref),
          _buildPayInvoiceButton(context),
        ];

      case Status.waitingBuyerInvoice:
        return [
          //_buildCloseButton(context),
          _buildCancelButton(context, ref),
          if (message.action == actions.Action.addInvoice)
            _buildAddInvoiceButton(context),
        ];
      case Status.settledHoldInvoice:
        return [
          _buildCloseButton(context),
          if (message.action == actions.Action.rate) _buildRateButton(context),
        ];
      case Status.active:
        return [
          //_buildCloseButton(context),
          _buildCancelButton(context, ref),
          _buildContactButton(context),
          // If user has not opened a dispute already
          if (message.action != actions.Action.disputeInitiatedByYou &&
              message.action != actions.Action.disputeInitiatedByPeer &&
              message.action != actions.Action.rate)
            _buildDisputeButton(ref),
          // If the action is "addInvoice" => show a button for the invoice screen.
          if (message.action == actions.Action.addInvoice)
            _buildAddInvoiceButton(context),
          // If the order is waiting for buyer to confirm fiat was sent
          if (session!.role == Role.buyer) _buildFiatSentButton(ref),
          // If the user is the seller & the buyer is done => show release button
          if (session.role == Role.seller) _buildReleaseButton(ref),
          // If the user is ready to rate
          if (message.action == actions.Action.rate) _buildRateButton(context),
        ];

      case Status.fiatSent:
        // Usually the user can open dispute if the other side doesn't confirm,
        // or just close the screen and wait.
        return [
          //_buildCloseButton(context),
          if (session!.role == Role.seller) _buildReleaseButton(ref),
          _buildDisputeButton(ref),
        ];

      case Status.cooperativelyCanceled:
        return [
          //_buildCloseButton(context),
          if (message.action == actions.Action.cooperativeCancelInitiatedByPeer)
            _buildCancelButton(context, ref),
        ];

      case Status.success:
        return [
          //_buildCloseButton(context),
          if (message.action != actions.Action.rateReceived)
            _buildRateButton(context),
        ];
      case Status.inProgress:
        return [
          _buildCancelButton(context, ref),
        ];
      case Status.expired:
      case Status.dispute:
      case Status.completedByAdmin:
      case Status.canceledByAdmin:
      case Status.settledByAdmin:
      case Status.canceled:
        return [
          _buildCloseButton(context),
        ];
    }
  }

  /// CONTACT
  Widget _buildContactButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        context.push('/chat_room/$orderId');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mostroGreen,
      ),
      child: const Text('CONTACT'),
    );
  }

  /// RELEASE
  Widget _buildReleaseButton(WidgetRef ref) {
    final orderDetailsNotifier =
        ref.read(orderNotifierProvider(orderId).notifier);

    return ElevatedButton(
      onPressed: () async {
        await orderDetailsNotifier.releaseOrder();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mostroGreen,
      ),
      child: const Text('RELEASE SATS'),
    );
  }

  /// FIAT_SENT
  Widget _buildFiatSentButton(WidgetRef ref) {
    final orderDetailsNotifier =
        ref.read(orderNotifierProvider(orderId).notifier);

    return ElevatedButton(
      onPressed: () async {
        await orderDetailsNotifier.sendFiatSent();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mostroGreen,
      ),
      child: const Text('FIAT SENT'),
    );
  }

  /// ADD INVOICE
  Widget _buildAddInvoiceButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        context.push('/add_invoice/$orderId');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mostroGreen,
      ),
      child: const Text('ADD INVOICE'),
    );
  }

  /// ADD INVOICE
  Widget _buildPayInvoiceButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        context.push('/pay_invoice/$orderId');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.mostroGreen,
      ),
      child: const Text('ADD INVOICE'),
    );
  }

  /// CANCEL
  Widget _buildCancelButton(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(orderNotifierProvider(orderId).notifier);
    return ElevatedButton(
      onPressed: () async {
        await notifier.cancelOrder();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.red1,
      ),
      child: const Text('CANCEL'),
    );
  }

  /// DISPUTE
  Widget _buildDisputeButton(WidgetRef ref) {
    final notifier = ref.read(orderNotifierProvider(orderId).notifier);
    return ElevatedButton(
      onPressed: () async {
        await notifier.disputeOrder();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.red1,
      ),
      child: const Text('DISPUTE'),
    );
  }

  /// CLOSE
  Widget _buildCloseButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.pop(),
      style: AppTheme.theme.outlinedButtonTheme.style,
      child: const Text('CLOSE'),
    );
  }

  /// RATE
  Widget _buildRateButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        context.push('/rate_user/$orderId');
      },
      style: AppTheme.theme.outlinedButtonTheme.style,
      child: const Text('RATE'),
    );
  }

  /// Format the date time to a user-friendly string with UTC offset
  String formatDateTime(DateTime dt) {
    final dateFormatter = DateFormat('EEE MMM dd yyyy HH:mm:ss');
    final formattedDate = dateFormatter.format(dt);
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final timeZoneName = dt.timeZoneName;
    return '$formattedDate GMT $sign$hours$minutes ($timeZoneName)';
  }
}
