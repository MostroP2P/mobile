import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/relay.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class RelaySelector extends ConsumerWidget {
  const RelaySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final relays = ref.watch(relaysProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: settings.relays.length,
        itemBuilder: (context, index) {
          final relay = relays[index];
          return Card(
            color: AppTheme.dark1,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                relay.url,
                style: const TextStyle(color: AppTheme.cream1),
              ),
              leading: Icon(
                Icons.circle,
                color: relay.isHealthy ? Colors.green : Colors.red,
                size: 16,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.cream1),
                    onPressed: () {
                      _showEditDialog(context, relay, ref);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.cream1),
                    onPressed: () {
                      ref.read(relaysProvider.notifier).removeRelay(relay.url);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static void showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          S.of(context)!.addRelay,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: S.of(context)!.relayUrl,
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: S.of(context)!.relayUrlHint,
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();
              if (input.isEmpty) return;
              
              // Show loading state
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.backgroundCard,
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.activeColor),
                      const SizedBox(width: 16),
                      Text(
                        S.of(context)!.relayTestingMessage,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
              
              // Capture localized strings before async operation
              final localizedStrings = (
                errorOnlySecure: S.of(context)!.relayErrorOnlySecure,
                errorNoHttp: S.of(context)!.relayErrorNoHttp,
                errorInvalidDomain: S.of(context)!.relayErrorInvalidDomain,
                errorAlreadyExists: S.of(context)!.relayErrorAlreadyExists,
                errorNotValid: S.of(context)!.relayErrorNotValid,
                relayAddedSuccessfully: S.of(context)!.relayAddedSuccessfully,
                relayAddedUnreachable: S.of(context)!.relayAddedUnreachable,
              );
              
              // Perform validation with localized error messages
              final result = await ref.read(relaysProvider.notifier)
                  .addRelayWithSmartValidation(
                    input,
                    errorOnlySecure: localizedStrings.errorOnlySecure,
                    errorNoHttp: localizedStrings.errorNoHttp,
                    errorInvalidDomain: localizedStrings.errorInvalidDomain,
                    errorAlreadyExists: localizedStrings.errorAlreadyExists,
                    errorNotValid: localizedStrings.errorNotValid,
                  );
              
              // Close loading dialog
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              
              if (result.success) {
                // Close add relay dialog
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                // Show success message with health status
                final message = result.isHealthy 
                    ? localizedStrings.relayAddedSuccessfully(result.normalizedUrl!)
                    : localizedStrings.relayAddedUnreachable(result.normalizedUrl!);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: result.isHealthy 
                          ? Colors.green.shade700 
                          : Colors.orange.shade700,
                    ),
                  );
                }
              } else {
                // Show specific error dialog
                if (dialogContext.mounted) {
                  showDialog(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.backgroundCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    title: Text(
                      S.of(context)!.invalidRelayTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: Text(
                      result.error!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          S.of(context)!.ok,
                          style: const TextStyle(
                            color: AppTheme.activeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.activeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              S.of(context)!.add,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Relay relay, WidgetRef ref) {
    final controller = TextEditingController(text: relay.url);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            S.of(context)!.editRelay,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: S.of(context)!.relayUrl,
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                S.of(context)!.cancel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty && newUrl != relay.url) {
                  final updatedRelay = relay.copyWith(url: newUrl);
                  ref
                      .read(relaysProvider.notifier)
                      .updateRelay(relay, updatedRelay);
                }
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              child: Text(
                S.of(context)!.save,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}
