import 'package:circular_countdown/circular_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/trades/models/trade_state.dart';
import 'package:mostro_mobile/features/trades/providers/trade_state_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/mostro_message_detail_widget.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String orderId;
  final TextTheme textTheme = AppTheme.theme.textTheme;

  TradeDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeState = ref.watch(tradeStateProvider(orderId));
    // If message is null or doesn't have an Order payload, show loading
    final orderPayload = tradeState.orderPayload;
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Display basic info about the trade:
                _buildSellerAmount(ref, tradeState),
                const SizedBox(height: 16),
                _buildOrderId(context),
                const SizedBox(height: 16),
                // Detailed info: includes the last Mostro message action text
                MostroMessageDetail(orderId: orderId),
                const SizedBox(height: 24),
                _buildCountDownTime(orderPayload.expiresAt),
                const SizedBox(height: 36),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCloseButton(context),
                    ..._buildActionButtons(
                      context,
                      ref,
                      tradeState,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a card showing the user is "selling/buying X sats for Y fiat" etc.
  Widget _buildSellerAmount(WidgetRef ref, TradeState tradeState) {
    final session = ref.watch(sessionProvider(orderId));

    final selling = session!.role == Role.seller ? 'selling' : 'buying';
    final currencyFlag = CurrencyUtils.getFlagFromCurrency(
      tradeState.orderPayload!.fiatCode,
    );

    final amountString =
        '${tradeState.orderPayload!.fiatAmount} ${tradeState.orderPayload!.fiatCode} $currencyFlag';

    // If `orderPayload.amount` is 0, the trade is "at market price"
    final isZeroAmount = (tradeState.orderPayload!.amount == 0);
    final satText = isZeroAmount ? '' : ' ${tradeState.orderPayload!.amount}';
    final priceText = isZeroAmount ? 'at market price' : '';

    final premium = tradeState.orderPayload!.premium;
    final premiumText = premium == 0
        ? ''
        : (premium > 0)
            ? 'with a +$premium% premium'
            : 'with a $premium% discount';

    // Payment methods - format multiple methods separated by commas
    final methodText = tradeState.orderPayload!.paymentMethod;

    final timestamp = formatDateTime(
      tradeState.orderPayload!.createdAt != null &&
              tradeState.orderPayload!.createdAt! > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              tradeState.orderPayload!.createdAt!)
          : DateTime.fromMillisecondsSinceEpoch(
              tradeState.orderPayload!.createdAt ?? 0,
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
                  'Payment methods: $methodText',
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
  /// Additional checks use `message.action` to refine which button to show.
  /// Following the Mostro protocol state machine for order flow.
  List<Widget> _buildActionButtons(
      BuildContext context, WidgetRef ref, TradeState tradeState) {
    final session = ref.watch(sessionProvider(orderId));
    final userRole = session?.role;

    switch (tradeState.status) {
      case Status.pending:
        // According to Mostro FSM: Pending state
        final widgets = <Widget>[];

        // FSM: In pending state, seller can cancel
        widgets.add(_buildNostrButton(
          'CANCEL',
          action: actions.Action.cancel,
          backgroundColor: AppTheme.red1,
          onPressed: () =>
              ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
        ));

        return widgets;

      case Status.waitingPayment:
        // According to Mostro FSM: waiting-payment state
        final widgets = <Widget>[];

        // FSM: Seller can pay-invoice and cancel
        if (userRole == Role.seller) {
          widgets.add(_buildNostrButton(
            'PAY INVOICE',
            action: actions.Action.waitingBuyerInvoice,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => context.push('/pay_invoice/$orderId'),
          ));
        }
        widgets.add(_buildNostrButton(
          'CANCEL',
          action: actions.Action.canceled,
          backgroundColor: AppTheme.red1,
          onPressed: () =>
              ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
        ));
        return widgets;

      case Status.waitingBuyerInvoice:
        // According to Mostro FSM: waiting-buyer-invoice state
        final widgets = <Widget>[];

        // FSM: Buyer can add-invoice and cancel
        if (userRole == Role.buyer) {
          widgets.add(_buildNostrButton(
            'ADD INVOICE',
            action: actions.Action.payInvoice,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => context.push('/add_invoice/$orderId'),
          ));
        }
        widgets.add(_buildNostrButton(
          'CANCEL',
          action: actions.Action.canceled,
          backgroundColor: AppTheme.red1,
          onPressed: () =>
              ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
        ));

        return widgets;

      case Status.settledHoldInvoice:
        if (tradeState.lastAction == actions.Action.rate) {
          return [
            // Rate button if applicable (common for both roles)
            _buildNostrButton(
              'RATE',
              action: actions.Action.rateReceived,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => context.push('/rate_user/$orderId'),
            )
          ];
        } else {
          return [];
        }

      case Status.active:
        // According to Mostro FSM: active state
        final widgets = <Widget>[];

        // Role-specific actions according to FSM
        if (userRole == Role.buyer) {
          // FSM: Buyer can fiat-sent
          if (tradeState.lastAction != actions.Action.fiatSentOk &&
              tradeState.lastAction != actions.Action.fiatSent) {
            widgets.add(_buildNostrButton(
              'FIAT SENT',
              action: actions.Action.fiatSentOk,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .sendFiatSent(),
            ));
          }

          // FSM: Buyer can cancel
          widgets.add(_buildNostrButton(
            'CANCEL',
            action: actions.Action.canceled,
            backgroundColor: AppTheme.red1,
            onPressed: () =>
                ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
          ));

          // FSM: Buyer can dispute
          if (tradeState.lastAction != actions.Action.disputeInitiatedByYou &&
              tradeState.lastAction != actions.Action.disputeInitiatedByPeer &&
              tradeState.lastAction != actions.Action.dispute) {
            widgets.add(_buildNostrButton(
              'DISPUTE',
              action: actions.Action.disputeInitiatedByYou,
              backgroundColor: AppTheme.red1,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .disputeOrder(),
            ));
          }
        } else if (userRole == Role.seller) {
          // FSM: Seller can cancel
          widgets.add(_buildNostrButton(
            'CANCEL',
            action: actions.Action.canceled,
            backgroundColor: AppTheme.red1,
            onPressed: () =>
                ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
          ));

          // FSM: Seller can dispute
          if (tradeState.lastAction != actions.Action.disputeInitiatedByYou &&
              tradeState.lastAction != actions.Action.disputeInitiatedByPeer &&
              tradeState.lastAction != actions.Action.dispute) {
            widgets.add(_buildNostrButton(
              'DISPUTE',
              action: actions.Action.disputeInitiatedByYou,
              backgroundColor: AppTheme.red1,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .disputeOrder(),
            ));
          }
        }

        // Rate button if applicable (common for both roles)
        if (tradeState.lastAction == actions.Action.rate) {
          widgets.add(_buildNostrButton(
            'RATE',
            action: actions.Action.rateReceived,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => context.push('/rate_user/$orderId'),
          ));
        }

        widgets.add(
          _buildContactButton(context),
        );

        return widgets;

      case Status.fiatSent:
        // According to Mostro FSM: fiat-sent state
        final widgets = <Widget>[];

        if (userRole == Role.seller) {
          // FSM: Seller can release
          widgets.add(_buildNostrButton(
            'RELEASE SATS',
            action: actions.Action.released,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => ref
                .read(orderNotifierProvider(orderId).notifier)
                .releaseOrder(),
          ));

          // FSM: Seller can cancel
          widgets.add(_buildNostrButton(
            'CANCEL',
            action: actions.Action.canceled,
            backgroundColor: AppTheme.red1,
            onPressed: () =>
                ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
          ));

          // FSM: Seller can dispute
          widgets.add(_buildNostrButton(
            'DISPUTE',
            action: actions.Action.disputeInitiatedByYou,
            backgroundColor: AppTheme.red1,
            onPressed: () => ref
                .read(orderNotifierProvider(orderId).notifier)
                .disputeOrder(),
          ));
        } else if (userRole == Role.buyer) {
          // FSM: Buyer can only dispute in fiat-sent state
          widgets.add(_buildNostrButton(
            'DISPUTE',
            action: actions.Action.disputeInitiatedByYou,
            backgroundColor: AppTheme.red1,
            onPressed: () => ref
                .read(orderNotifierProvider(orderId).notifier)
                .disputeOrder(),
          ));
        }

        return widgets;

      case Status.cooperativelyCanceled:
        // According to Mostro FSM: cooperatively-canceled state
        final widgets = <Widget>[];

        // Add confirm cancel if cooperative cancel was initiated by peer
        if (tradeState.lastAction ==
            actions.Action.cooperativeCancelInitiatedByPeer) {
          widgets.add(_buildNostrButton(
            'CONFIRM CANCEL',
            action: actions.Action.cooperativeCancelAccepted,
            backgroundColor: AppTheme.red1,
            onPressed: () =>
                ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
          ));
        }

        return widgets;

      case Status.success:
        // According to Mostro FSM: success state
        // Both buyer and seller can only rate
        final widgets = <Widget>[];

        // FSM: Both roles can rate counterparty if not already rated
        if (tradeState.lastAction != actions.Action.rateReceived) {
          widgets.add(_buildNostrButton(
            'RATE',
            action: actions.Action.rateReceived,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => context.push('/rate_user/$orderId'),
          ));
        }

        return widgets;

      case Status.inProgress:
        // According to Mostro FSM: in-progress is a transitional state
        // This is not explicitly in the FSM but we follow cancel rules as active state
        final widgets = <Widget>[];

        // Both roles can cancel during in-progress state, similar to active
        widgets.add(_buildNostrButton(
          'CANCEL',
          action: actions.Action.canceled,
          backgroundColor: AppTheme.red1,
          onPressed: () =>
              ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
        ));

        return widgets;

      // Terminal states according to Mostro FSM
      case Status.expired:
      case Status.dispute:
      case Status.completedByAdmin:
      case Status.canceledByAdmin:
      case Status.settledByAdmin:
      case Status.canceled:
        // No actions allowed in these terminal states
        return [];
    }
  }

  /// Helper method to build a NostrResponsiveButton with common properties
  Widget _buildNostrButton(
    String label, {
    required actions.Action action,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return MostroReactiveButton(
      label: label,
      buttonStyle: ButtonStyleType.raised,
      orderId: orderId,
      action: action,
      backgroundColor: backgroundColor,
      onPressed: onPressed,
      showSuccessIndicator: true,
      timeout: const Duration(seconds: 30),
    );
  }

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

  /// CLOSE
  Widget _buildCloseButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.pop(),
      style: AppTheme.theme.outlinedButtonTheme.style,
      child: const Text('CLOSE'),
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
