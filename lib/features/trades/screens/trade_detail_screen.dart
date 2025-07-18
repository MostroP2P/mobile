import 'package:circular_countdown/circular_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';
import 'package:mostro_mobile/features/trades/widgets/mostro_message_detail_widget.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if this is a pending order created by the user
    final session = ref.watch(sessionProvider(orderId));
    final isPending = tradeState.status == Status.pending;
    final isCreator = _isUserCreator(session, tradeState);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: OrderAppBar(title: S.of(context)!.orderDetailsTitle),
      body: Builder(
        builder: (context) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Display basic info about the trade:
                _buildSellerAmount(context, ref, tradeState),
                const SizedBox(height: 16),
                _buildOrderId(context),
                const SizedBox(height: 16),
                // For pending orders created by the user, show creator's reputation
                if (isPending && isCreator) ...[
                  _buildCreatorReputation(context, tradeState),
                  const SizedBox(height: 16),
                ] else ...[
                  // Use spread operator here too
                  // Detailed info: includes the last Mostro message action text
                  MostroMessageDetail(orderId: orderId),
                ],
                const SizedBox(height: 24),
                // Show countdown timer only for specific statuses
                _CountdownWidget(
                  orderId: orderId,
                  tradeState: tradeState,
                  expiresAtTimestamp: orderPayload.expiresAt != null
                      ? orderPayload.expiresAt! * 1000
                      : null,
                ),
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
  Widget _buildSellerAmount(
      BuildContext context, WidgetRef ref, OrderState tradeState) {
    final session = ref.watch(sessionProvider(orderId));
    final isPending = tradeState.status == Status.pending;

    // Determine if the user is the creator of the order based on role and order type
    final isCreator = _isUserCreator(session, tradeState);

    // For pending orders created by the user, show a notification message
    if (isPending && isCreator) {
      final selling = session?.role == Role.seller
          ? S.of(context)!.selling
          : S.of(context)!.buying;
      // Currency information is now handled by OrderAmountCard

      // If `orderPayload.amount` is 0, the trade is "at market price"
      final isZeroAmount = (tradeState.order!.amount == 0);
      final priceText = isZeroAmount ? S.of(context)!.atMarketPrice : '';

      final paymentMethod = tradeState.order!.paymentMethod;
      final createdOn = formatDateTime(
        tradeState.order!.createdAt != null && tradeState.order!.createdAt! > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                tradeState.order!.createdAt! * 1000)
            : session?.startTime ?? DateTime.now(),
        context,
      );

      final hasFixedSatsAmount = tradeState.order!.amount != 0;
      final satAmount =
          hasFixedSatsAmount ? ' ${tradeState.order!.amount}' : '';

      return Column(
        children: [
          NotificationMessageCard(
            message: S.of(context)!.youCreatedOfferMessage,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 16),
          OrderAmountCard(
            title: selling == S.of(context)!.selling
                ? S.of(context)!.youAreSellingTitle(satAmount)
                : S.of(context)!.youAreBuyingTitle(satAmount),
            amount: (tradeState.order!.minAmount != null &&
                    tradeState.order!.maxAmount != null &&
                    tradeState.order!.minAmount != tradeState.order!.maxAmount)
                ? "${tradeState.order!.minAmount} - ${tradeState.order!.maxAmount}"
                : tradeState.order!.fiatAmount.toString(),
            currency: tradeState.order!.fiatCode,
            priceText: priceText,
          ),
          const SizedBox(height: 16),
          PaymentMethodCard(
            paymentMethod: paymentMethod,
          ),
          const SizedBox(height: 16),
          CreatedDateCard(
            createdDate: createdOn,
          ),
        ],
      );
    }

    // For non-pending orders or orders not created by the user, use the original display
    final selling = session?.role == Role.seller
        ? S.of(context)!.selling
        : S.of(context)!.buying;

    final hasFixedSatsAmount = tradeState.order!.amount != 0;
    final satAmount = hasFixedSatsAmount ? ' ${tradeState.order!.amount}' : '';
    final priceText = !hasFixedSatsAmount ? S.of(context)!.atMarketPrice : '';

    final premium = tradeState.order!.premium;
    final premiumText = premium == 0
        ? ''
        : (premium > 0)
            ? S.of(context)!.withPremiumPercent(premium.toString())
            : S.of(context)!.withDiscountPercent(premium.abs().toString());

    // Payment method
    final method = tradeState.order!.paymentMethod;
    final timestamp = formatDateTime(
      tradeState.order!.createdAt != null && tradeState.order!.createdAt! > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              tradeState.order!.createdAt! * 1000)
          : session?.startTime ?? DateTime.now(),
      context,
    );

    return Column(
      children: [
        OrderAmountCard(
          title: selling == S.of(context)!.selling
              ? S.of(context)!.youAreSellingTitle(satAmount)
              : S.of(context)!.youAreBuyingTitle(satAmount),
          amount: (tradeState.order!.minAmount != null &&
                  tradeState.order!.maxAmount != null &&
                  tradeState.order!.minAmount != tradeState.order!.maxAmount)
              ? "${tradeState.order!.minAmount} - ${tradeState.order!.maxAmount}"
              : tradeState.order!.fiatAmount.toString(),
          currency: tradeState.order!.fiatCode,
          priceText: priceText,
          premiumText: premiumText,
        ),
        const SizedBox(height: 16),
        PaymentMethodCard(
          paymentMethod: method,
        ),
        const SizedBox(height: 16),
        CreatedDateCard(
          createdDate: timestamp,
        ),
      ],
    );
  }

  /// Show a card with the order ID that can be copied.
  Widget _buildOrderId(BuildContext context) {
    return OrderIdCard(
      orderId: orderId,
    );
  }

  /// Main action button area, switching on `orderPayload.status`.
  /// Additional checks use `message.action` to refine which button to show.
  /// Following the Mostro protocol state machine for order flow.
  List<Widget> _buildActionButtons(
      BuildContext context, WidgetRef ref, OrderState tradeState) {
    final session = ref.watch(sessionProvider(orderId));
    final userRole = session?.role;

    if (userRole == null) {
      return [];
    }

    final userActions = tradeState.getActions(userRole);
    if (userActions.isEmpty) return [];

    final widgets = <Widget>[];

    for (final action in userActions) {
      // FSM-driven action mapping: ensure all actions are handled
      switch (action) {
        case actions.Action.cancel:
          String cancelMessage;

          if (tradeState.status == Status.active ||
              tradeState.status == Status.fiatSent) {
            if (tradeState.action ==
                actions.Action.cooperativeCancelInitiatedByPeer) {
              cancelMessage = S.of(context)!.acceptCancelMessage;
            } else {
              cancelMessage = S.of(context)!.cooperativeCancelMessage;
            }
          } else {
            cancelMessage = S.of(context)!.areYouSureCancel;
          }

          final buttonController = MostroReactiveButtonController();
          widgets.add(_buildNostrButton(
            S.of(context)!.cancel.toUpperCase(),
            action: action,
            backgroundColor: AppTheme.red1,
            controller: buttonController,
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(S.of(context)!.cancelTradeDialogTitle),
                  content: Text(cancelMessage),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: Text(S.of(context)!.no),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        context.pop(true);
                        ref
                            .read(orderNotifierProvider(orderId).notifier)
                            .cancelOrder();
                      },
                      child: Text(S.of(context)!.yes),
                    ),
                  ],
                ),
              );

              // Reset loading state if dialog was cancelled
              if (result != true) {
                buttonController.resetLoading();
              }
            },
          ));
          break;

        case actions.Action.payInvoice:
          if (userRole == Role.seller) {
            final hasPaymentRequest = tradeState.paymentRequest != null;

            if (hasPaymentRequest) {
              widgets.add(_buildNostrButton(
                S.of(context)!.payInvoiceButton,
                action: actions.Action.payInvoice,
                backgroundColor: AppTheme.mostroGreen,
                onPressed: () => context.push('/pay_invoice/$orderId'),
              ));
            }
          }
          break;

        case actions.Action.addInvoice:
          if (userRole == Role.buyer) {
            widgets.add(_buildNostrButton(
              S.of(context)!.addInvoiceButton,
              action: actions.Action.addInvoice,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => context.push('/add_invoice/$orderId'),
            ));
          }
          break;

        case actions.Action.fiatSent:
          if (userRole == Role.buyer) {
            widgets.add(_buildNostrButton(
              S.of(context)!.fiatSentButton,
              action: actions.Action.fiatSent,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .sendFiatSent(),
            ));
          }
          break;

        case actions.Action.disputeInitiatedByYou:
        case actions.Action.disputeInitiatedByPeer:
        case actions.Action.dispute:
          // Only allow dispute if not already disputed
          if (tradeState.action != actions.Action.disputeInitiatedByYou &&
              tradeState.action != actions.Action.disputeInitiatedByPeer &&
              tradeState.action != actions.Action.dispute) {
            widgets.add(_buildNostrButton(
              S.of(context)!.disputeButton,
              action: actions.Action.disputeInitiatedByYou,
              backgroundColor: AppTheme.red1,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .disputeOrder(),
            ));
          }
          break;

        case actions.Action.release:
          if (userRole == Role.seller) {
            widgets.add(_buildNostrButton(
              S.of(context)!.release.toUpperCase(),
              action: actions.Action.release,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => ref
                  .read(orderNotifierProvider(orderId).notifier)
                  .releaseOrder(),
            ));
          }
          break;

        case actions.Action.takeSell:
          if (userRole == Role.buyer) {
            widgets.add(_buildNostrButton(
              S.of(context)!.takeSell,
              action: actions.Action.takeSell,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => context.push('/take_sell/$orderId'),
            ));
          }
          break;

        case actions.Action.takeBuy:
          if (userRole == Role.seller) {
            widgets.add(_buildNostrButton(
              S.of(context)!.takeBuy,
              action: actions.Action.takeBuy,
              backgroundColor: AppTheme.mostroGreen,
              onPressed: () => context.push('/take_buy/$orderId'),
            ));
          }
          break;

        case actions.Action.cooperativeCancelInitiatedByYou:
          widgets.add(_buildNostrButton(
            S.of(context)!.cancelPendingButton,
            action: actions.Action.cooperativeCancelInitiatedByYou,
            backgroundColor: Colors.grey,
            onPressed: null,
          ));
          break;

        case actions.Action.cooperativeCancelInitiatedByPeer:
          widgets.add(_buildNostrButton(
            S.of(context)!.acceptCancelButton,
            action: actions.Action.cooperativeCancelAccepted,
            backgroundColor: AppTheme.red1,
            onPressed: () =>
                ref.read(orderNotifierProvider(orderId).notifier).cancelOrder(),
          ));
          break;

        case actions.Action.cooperativeCancelAccepted:
          break;

        case actions.Action.purchaseCompleted:
          widgets.add(_buildNostrButton(
            S.of(context)!.completePurchaseButton,
            action: actions.Action.purchaseCompleted,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => ref
                .read(orderNotifierProvider(orderId).notifier)
                .releaseOrder(),
          ));
          break;

        case actions.Action.buyerTookOrder:
          widgets.add(_buildContactButton(context));
          break;

        case actions.Action.rate:
        case actions.Action.rateUser:
        case actions.Action.rateReceived:
          widgets.add(_buildNostrButton(
            S.of(context)!.rate.toUpperCase(),
            action: actions.Action.rate,
            backgroundColor: AppTheme.mostroGreen,
            onPressed: () => context.push('/rate_user/$orderId'),
          ));
          break;

        case actions.Action.sendDm:
          widgets.add(_buildContactButton(context));
          break;

        case actions.Action.holdInvoicePaymentCanceled:
        case actions.Action.buyerInvoiceAccepted:
        case actions.Action.waitingSellerToPay:
        case actions.Action.waitingBuyerInvoice:
        case actions.Action.adminCancel:
        case actions.Action.adminCanceled:
        case actions.Action.adminSettle:
        case actions.Action.adminSettled:
        case actions.Action.adminAddSolver:
        case actions.Action.adminTakeDispute:
        case actions.Action.adminTookDispute:
        case actions.Action.paymentFailed:
        case actions.Action.invoiceUpdated:
        case actions.Action.tradePubkey:
        case actions.Action.cantDo:
        case actions.Action.released:
          break;
        default:
          break;
      }
    }

    return widgets;
  }

  /// Helper method to build a NostrResponsiveButton with common properties
  Widget _buildNostrButton(
    String label, {
    required actions.Action action,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Key? key,
    MostroReactiveButtonController? controller,
  }) {
    return MostroReactiveButton(
      key: key,
      label: label,
      buttonStyle: ButtonStyleType.raised,
      orderId: orderId,
      action: action,
      backgroundColor: backgroundColor,
      onPressed: onPressed ?? () {}, // Provide empty function when null
      showSuccessIndicator: true,
      timeout: const Duration(seconds: 30),
      controller: controller,
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
      child: Text(S.of(context)!.contact),
    );
  }

  /// CLOSE
  Widget _buildCloseButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.go('/order_book'),
      style: AppTheme.theme.outlinedButtonTheme.style,
      child: Text(S.of(context)!.close),
    );
  }

  /// Build a card showing the creator's reputation with rating, reviews and days
  Widget _buildCreatorReputation(BuildContext context, OrderState tradeState) {
    // In trade_detail_screen.dart, we don't have direct access to rating as in NostrEvent
    // For now, we use default values
    // TODO: Implement extraction of creator rating data
    const rating = 3.1;
    const reviews = 15;
    const days = 7;

    return CreatorReputationCard(
      rating: rating,
      reviews: reviews,
      days: days,
    );
  }

  /// Helper method to determine if the current user is the creator of the order
  /// based on their role (buyer/seller) and the order type (buy/sell)
  bool _isUserCreator(Session? session, OrderState tradeState) {
    if (session == null || session.role == null || tradeState.order == null) {
      return false;
    }
    return session.role == Role.buyer
        ? tradeState.order!.kind == OrderType.buy
        : tradeState.order!.kind == OrderType.sell;
  }

  /// Format the date time to a user-friendly string with internationalization
  String formatDateTime(DateTime dt, [BuildContext? context]) {
    if (context != null) {
      // Use internationalized date format
      final dateFormatter =
          DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
      final timeFormatter =
          DateFormat.Hm(Localizations.localeOf(context).languageCode);
      final formattedDate = dateFormatter.format(dt);
      final formattedTime = timeFormatter.format(dt);

      // Use the internationalized string for "Created on: date"
      return S.of(context)!.createdOnDate('$formattedDate $formattedTime');
    } else {
      // Fallback if context is not available
      final dateFormatter = DateFormat('EEE, MMM dd yyyy');
      final timeFormatter = DateFormat('HH:mm');
      final formattedDate = dateFormatter.format(dt);
      final formattedTime = timeFormatter.format(dt);

      return '$formattedDate at $formattedTime';
    }
  }
}

/// Widget that displays a real-time countdown timer that updates every second
class _CountdownWidget extends ConsumerWidget {
  final String orderId;
  final OrderState tradeState;
  final int? expiresAtTimestamp;

  const _CountdownWidget({
    required this.orderId,
    required this.tradeState,
    this.expiresAtTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the countdown time provider for real-time updates
    final timeAsync = ref.watch(countdownTimeProvider);
    final messagesAsync = ref.watch(mostroMessageHistoryProvider(orderId));

    return timeAsync.when(
      data: (currentTime) {
        return messagesAsync.maybeWhen(
          data: (messages) {
            final countdownWidget = _buildCountDownTime(
              context,
              ref,
              tradeState,
              messages,
              expiresAtTimestamp,
            );

            if (countdownWidget != null) {
              return Column(
                children: [
                  countdownWidget,
                  const SizedBox(height: 36),
                ],
              );
            } else {
              return const SizedBox(height: 12);
            }
          },
          orElse: () => const SizedBox(height: 12),
        );
      },
      loading: () => const SizedBox(height: 12),
      error: (error, stack) => const SizedBox(height: 12),
    );
  }

  /// Build a circular countdown timer only for specific order statuses.
  /// Shows countdown ONLY for: Pending, Waiting-buyer-invoice, Waiting-payment
  /// - Pending: uses expirationHours from Mostro instance
  /// - Waiting-buyer-invoice: countdown from message timestamp + expirationSeconds
  /// - Waiting-payment: countdown from message timestamp + expirationSeconds
  /// - All other states: no countdown timer
  Widget? _buildCountDownTime(
      BuildContext context,
      WidgetRef ref,
      OrderState tradeState,
      List<MostroMessage> messages,
      int? expiresAtTimestamp) {
    final status = tradeState.status;
    final now = DateTime.now();
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

    // Show countdown ONLY for these 3 specific statuses
    if (status == Status.pending) {
      // Pending orders: use expirationHours
      final expHours =
          mostroInstance?.expirationHours ?? 24; // 24 hours fallback
      final countdownDuration = Duration(hours: expHours);

      // Handle edge case: invalid timestamp
      if (expiresAtTimestamp != null && expiresAtTimestamp <= 0) {
        expiresAtTimestamp = null;
      }

      final expiration = expiresAtTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtTimestamp)
          : now.add(countdownDuration);

      // Handle edge case: expiration in the past
      if (expiration.isBefore(now.subtract(const Duration(hours: 1)))) {
        // If expiration is more than 1 hour in the past, likely invalid
        return null;
      }

      final Duration difference = expiration.isAfter(now)
          ? expiration.difference(now)
          : const Duration();

      final hoursLeft = difference.inHours.clamp(0, expHours);
      final minutesLeft = difference.inMinutes % 60;
      final secondsLeft = difference.inSeconds % 60;

      final formattedTime =
          '${hoursLeft.toString().padLeft(2, '0')}:${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

      return Column(
        children: [
          CircularCountdown(
            countdownTotal: expHours,
            countdownRemaining: hoursLeft,
          ),
          const SizedBox(height: 16),
          Text(S.of(context)!.timeLeftLabel(formattedTime)),
        ],
      );
    } else if (status == Status.waitingBuyerInvoice ||
        status == Status.waitingPayment) {
      // Find the message that triggered this state
      final stateMessage = _findMessageForState(messages, status);
      if (stateMessage?.timestamp == null) {
        // If no message found, don't show countdown
        return null;
      }

      final expSecs =
          mostroInstance?.expirationSeconds ?? 900; // 15 minutes fallback
      final expMinutes = (expSecs / 60).round();

      // Validate timestamp
      final messageTimestamp = stateMessage!.timestamp!;
      if (messageTimestamp <= 0) {
        return null;
      }

      // Calculate expiration from when the message was received
      final messageTime = DateTime.fromMillisecondsSinceEpoch(messageTimestamp);
      
      // Handle edge case: message timestamp in the future
      if (messageTime.isAfter(now.add(const Duration(hours: 1)))) {
        // If message is more than 1 hour in the future, likely invalid
        return null;
      }

      final expiration = messageTime.add(Duration(seconds: expSecs));

      final Duration difference = expiration.isAfter(now)
          ? expiration.difference(now)
          : const Duration();

      final minutesLeft = difference.inMinutes.clamp(0, expMinutes);
      final secondsLeft = difference.inSeconds % 60;

      final formattedTime =
          '${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

      return Column(
        children: [
          CircularCountdown(
            countdownTotal: expMinutes,
            countdownRemaining: minutesLeft,
          ),
          const SizedBox(height: 16),
          Text(S.of(context)!.timeLeftLabel(formattedTime)),
        ],
      );
    } else {
      // All other statuses: NO countdown timer
      return null;
    }
  }

  /// Find the message that triggered the current state
  /// Returns null if no valid message is found
  MostroMessage? _findMessageForState(
      List<MostroMessage> messages, Status status) {
    // Filter out messages with invalid timestamps
    final validMessages = messages
        .where((m) => m.timestamp != null && m.timestamp! > 0)
        .toList();

    if (validMessages.isEmpty) {
      return null;
    }

    // Sort messages by timestamp (newest first)
    final sortedMessages = List<MostroMessage>.from(validMessages)
      ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

    // Find the message that caused this state
    for (final message in sortedMessages) {
      // Additional validation: ensure timestamp is not in the future
      final messageTime = DateTime.fromMillisecondsSinceEpoch(message.timestamp!);
      if (messageTime.isAfter(DateTime.now().add(const Duration(hours: 1)))) {
        continue; // Skip messages with future timestamps
      }

      if (status == Status.waitingBuyerInvoice &&
          (message.action == actions.Action.addInvoice ||
              message.action == actions.Action.waitingBuyerInvoice)) {
        return message;
      } else if (status == Status.waitingPayment &&
          (message.action == actions.Action.payInvoice ||
              message.action == actions.Action.waitingSellerToPay)) {
        return message;
      }
    }
    return null;
  }
}
