import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';

class TakeOrderScreen extends ConsumerStatefulWidget {
  final String orderId;
  final OrderType orderType;

  const TakeOrderScreen({
    super.key,
    required this.orderId,
    required this.orderType,
  });

  @override
  ConsumerState<TakeOrderScreen> createState() => _TakeOrderScreenState();
}

class _TakeOrderScreenState extends ConsumerState<TakeOrderScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to notifier state changes:
    ref.listen<MostroMessage>(
      orderNotifierProvider(widget.orderId),
      (previous, next) {
        // If we’re waiting for a response and the state changes from our initial state,
        // then navigate accordingly.
        if (_isLoading && previous?.action == (widget.orderType == OrderType.buy ? actions.Action.takeBuy : actions.Action.takeSell)) {
          setState(() {
            _isLoading = false;
          });
          // For example, if next.action is now Action.payInvoice,
          // navigate to the Lightning Invoice input screen:
          if (next.action == actions.Action.payInvoice) {
            context.go('/pay_lightning_invoice', extra: widget.orderId);
          }
          // Or, if you expect a different screen (e.g., for a buyer, to create an invoice),
          // adjust the navigation accordingly.
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we are in loading state, show a simple loading screen.
    if (_isLoading) {
      return Scaffold(
        appBar: OrderAppBar(title: 'Processing Order'),
        backgroundColor: AppTheme.dark1,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Otherwise, build the normal UI. (For brevity, this example uses a simple placeholder.)
    return Scaffold(
      appBar: OrderAppBar(
          title: widget.orderType == OrderType.buy ? 'BUY ORDER' : 'SELL ORDER'),
      backgroundColor: AppTheme.dark1,
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final confirmed = await _showConfirmationDialog();
            if (confirmed) {
              setState(() {
                _isLoading = true;
              });
              // Depending on order type, call the appropriate notifier method.
              final notifier = ref.read(orderNotifierProvider(widget.orderId).notifier);
              // Pass along any required parameters (e.g., fiat amount or LN address) as needed.
              // Here we assume null values for simplicity.
              if (widget.orderType == OrderType.buy) {
                await notifier.takeBuyOrder(widget.orderId, null);
              } else {
                await notifier.takeSellOrder(widget.orderId, null, null);
              }
              // The ref.listen above will catch the state update and trigger navigation.
            }
          },
          child: const Text('CONTINUE'),
        ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Order'),
              content: const Text('Do you really want to take this order?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
