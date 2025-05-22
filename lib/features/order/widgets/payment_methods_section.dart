import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';

class PaymentMethodsSection extends ConsumerWidget {
  final List<String> selectedMethods;
  final bool showCustomField;
  final TextEditingController customController;
  final Function(List<String>, bool) onMethodsChanged;

  const PaymentMethodsSection({
    super.key,
    required this.selectedMethods,
    required this.showCustomField,
    required this.customController,
    required this.onMethodsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider) ?? 'USD';

    final paymentMethodsData = ref.watch(paymentMethodsDataProvider);

    return FormSection(
      title: 'Payment methods for $selectedFiatCode',
      icon: const Icon(Icons.credit_card, color: Color(0xFF8CC63F), size: 18),
      iconBackgroundColor: const Color(0xFF8CC63F).withOpacity(0.3),
      extraContent: showCustomField
          ? Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: TextField(
                controller: customController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter custom payment method',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF8CC63F)),
                  ),
                ),
              ),
            )
          : null,
      child: paymentMethodsData.when(
        loading: () => const Text('Loading payment methods...',
            style: TextStyle(color: Colors.white)),
        error: (error, _) => Text('Error loading payment methods: $error',
            style: TextStyle(color: Colors.red)),
        data: (data) {
          final displayText = selectedMethods.isEmpty
              ? 'Select payment methods'
              : selectedMethods.join(', ');

          List<String> availableMethods = [];
          if (data.containsKey(selectedFiatCode)) {
            availableMethods = List<String>.from(data[selectedFiatCode]);
          } else {
            availableMethods = List<String>.from(data['default'] ??
                ['Bank Transfer', 'Cash in person', 'Other']);
          }

          return InkWell(
            onTap: () {
              _showPaymentMethodsDialog(
                context,
                availableMethods,
                selectedMethods,
                showCustomField,
                onMethodsChanged,
                customController,
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
    bool showCustomField,
    Function(List<String>, bool) onMethodsChanged,
    TextEditingController customController,
  ) {
    if (!availableMethods.contains('Other')) {
      availableMethods = [...availableMethods, 'Other'];
    }

    List<String> dialogSelectedMethods = List<String>.from(selectedMethods);
    bool dialogShowOtherField = dialogSelectedMethods.contains('Other');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: const Text(
                'Select Payment Methods',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...availableMethods.map((method) => CheckboxListTile(
                            title: Text(method,
                                style: const TextStyle(color: Colors.white)),
                            value: dialogSelectedMethods.contains(method),
                            activeColor: const Color(0xFF8CC63F),
                            checkColor: Colors.black,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  dialogSelectedMethods.add(method);
                                  if (method == 'Other') {
                                    dialogShowOtherField = true;
                                  }
                                } else {
                                  dialogSelectedMethods.remove(method);
                                  if (method == 'Other') {
                                    dialogShowOtherField = false;
                                  }
                                }
                              });
                            },
                          )),
                      if (dialogShowOtherField) ...[
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (context, setState) {
                            String customValue = customController.text;
                            return TextField(
                              controller:
                                  TextEditingController(text: customValue),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Enter custom payment method',
                                hintStyle: TextStyle(color: Colors.grey),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFF8CC63F)),
                                ),
                              ),
                              onChanged: (value) {
                                customValue = value;
                                customController.text = value;
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    onMethodsChanged(
                        dialogSelectedMethods, dialogShowOtherField);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Confirm',
                      style: TextStyle(color: Color(0xFF8CC63F))),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
