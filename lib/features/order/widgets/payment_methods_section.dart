import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class PaymentMethodsSection extends ConsumerWidget {
  final List<String> selectedMethods;
  final TextEditingController customController;
  final Function(List<String>) onMethodsChanged;

  /// Helper function to translate payment method names
  String _translatePaymentMethod(String method, BuildContext context) {
    switch (method) {
      case 'Bank Transfer':
        return S.of(context)!.bankTransfer;
      case 'Cash in person':
        return S.of(context)!.cashInPerson;
      case 'Other':
        return S.of(context)!.other;
      default:
        return method;
    }
  }

  const PaymentMethodsSection({
    super.key,
    required this.selectedMethods,
    required this.customController,
    required this.onMethodsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider);

    final paymentMethodsData = ref.watch(paymentMethodsDataProvider);

    return FormSection(
      title: S.of(context)!.paymentMethodsForCurrency(selectedFiatCode ?? ''),
      icon: const Icon(Icons.credit_card, color: AppTheme.mostroGreen, size: 18),
      iconBackgroundColor: AppTheme.mostroGreen.withValues(alpha: 0.3),
      extraContent: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
          child: TextField(
            key: const Key('paymentMethodField'),
            controller: customController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: S.of(context)!.enterCustomPaymentMethod,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      child: paymentMethodsData.when(
        loading: () => Text(S.of(context)!.loadingPaymentMethods,
            style: const TextStyle(color: Colors.white)),
        error: (error, _) => Text(
            S.of(context)!.errorLoadingPaymentMethods(error.toString()),
            style: const TextStyle(color: Colors.red)),
        data: (data) {
          final displayText = selectedMethods.isEmpty
              ? S.of(context)!.selectPaymentMethods
              : selectedMethods.join(', ');

          List<String> availableMethods = [];
          if (data.containsKey(selectedFiatCode)) {
            availableMethods = List<String>.from(data[selectedFiatCode])
                .map((method) => _translatePaymentMethod(method, context))
                .toList();
          } else {
            availableMethods = List<String>.from(data['default'] ?? ['Bank Transfer', 'Cash in person', 'Other'])
                .map((method) => _translatePaymentMethod(method, context))
                .toList();
          }

          return InkWell(
            onTap: () {
              _showPaymentMethodsDialog(
                context,
                availableMethods,
                selectedMethods,
                onMethodsChanged,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    displayText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selectedMethods.isEmpty ? Colors.grey : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPaymentMethodsDialog(
    BuildContext context,
    List<String> availableMethods,
    List<String> selectedMethods,
    Function(List<String>) onMethodsChanged,
  ) {
    // Remove "Other" from available methods since custom field is always visible
    final translatedOther = _translatePaymentMethod('Other', context);
    availableMethods = availableMethods
        .where((m) => m != translatedOther)
        .toList();

    // Normalize to current locale so checkbox states align with localized labels
    final localizedSelected = selectedMethods
        .map((m) => _translatePaymentMethod(m, context))
        .where((m) => m != translatedOther)
        .toList();
    List<String> dialogSelectedMethods = List<String>.from(localizedSelected);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.backgroundCard,
              title: Text(
                S.of(context)!.selectPaymentMethodsTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: availableMethods.map((method) => CheckboxListTile(
                          title: Text(method,
                              style: const TextStyle(color: Colors.white)),
                          value: dialogSelectedMethods.contains(method),
                          activeColor: AppTheme.mostroGreen,
                          checkColor: Colors.black,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected == true) {
                                dialogSelectedMethods.add(method);
                              } else {
                                dialogSelectedMethods.remove(method);
                              }
                            });
                          },
                        )).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    S.of(context)!.cancel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    onMethodsChanged(dialogSelectedMethods);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.activeColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.confirm,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
