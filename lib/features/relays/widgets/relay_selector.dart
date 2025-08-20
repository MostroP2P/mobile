import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/relay.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class RelaySelector extends ConsumerWidget {
  const RelaySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relaysNotifier = ref.watch(relaysProvider.notifier);
    final mostroRelays = relaysNotifier.mostroRelaysWithStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description only
        Text(
          S.of(context)!.relaysDescription,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        
        // Relay list
        if (mostroRelays.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.dark1.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context)!.noMostroRelaysAvailable,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...mostroRelays.map((relayInfo) {
            return _buildRelayItem(context, ref, relayInfo);
          }),
        
        const SizedBox(height: 24),
        
        // Add relay button - aligned to the right
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () async {
                await showAddDialog(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                S.of(context)!.addRelay,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelayItem(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Grey dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          
          // Relay URL
          Expanded(
            child: Text(
              relayInfo.url,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Switch and label - aligned with overflow protection
          Container(
            width: 140, // Increased width to show full text
            padding: const EdgeInsets.only(right: 16), // Prevent overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildRelaySwitch(context, ref, relayInfo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    relayInfo.isActive ? S.of(context)!.activated : S.of(context)!.deactivated,
                    style: const TextStyle(
                      color: AppTheme.textSecondary, // Use same grey as description
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaySwitch(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) {
    final isActive = relayInfo.isActive;
    
    return GestureDetector(
      onTap: () async {
        await _handleRelayToggle(context, ref, relayInfo);
      },
      child: Container(
        width: 50,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle relay toggle with safety checks and confirmation dialogs
  Future<void> _handleRelayToggle(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) async {
    final isCurrentlyBlacklisted = !relayInfo.isActive;
    final isDefaultMostroRelay = relayInfo.url.startsWith('wss://relay.mostro.network');
    final relaysNotifier = ref.read(relaysProvider.notifier);
    
    // If removing from blacklist, proceed directly
    if (isCurrentlyBlacklisted) {
      await relaysNotifier.toggleMostroRelayBlacklist(relayInfo.url);
      return;
    }
    
    // Check if this would be the last active relay - BLOCK the action
    if (relaysNotifier.wouldLeaveNoActiveRelays(relayInfo.url)) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.dark2,
            title: Text(
              S.of(context)!.cannotBlacklistLastRelayTitle,
              style: const TextStyle(color: AppTheme.cream1),
            ),
            content: Text(
              S.of(context)!.cannotBlacklistLastRelayMessage,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  S.of(context)!.cannotBlacklistLastRelayOk,
                  style: const TextStyle(color: AppTheme.cream1),
                ),
              ),
            ],
          );
        },
      );
      return; // Block the action - do NOT proceed
    }
    
    // If it's the default relay, show confirmation dialog
    if (isDefaultMostroRelay) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.dark2,
            title: Text(
              S.of(context)!.blacklistDefaultRelayTitle,
              style: const TextStyle(color: AppTheme.cream1),
            ),
            content: Text(
              S.of(context)!.blacklistDefaultRelayMessage,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  S.of(context)!.blacklistDefaultRelayCancel,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  S.of(context)!.blacklistDefaultRelayConfirm,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );
      
      // Proceed only if user confirmed
      if (shouldProceed == true) {
        await relaysNotifier.toggleMostroRelayBlacklist(relayInfo.url);
      }
    } else {
      // Regular relay - proceed directly
      await relaysNotifier.toggleMostroRelayBlacklist(relayInfo.url);
    }
  }

  /// Show dialog to add a new user relay with full validation
  Future<void> showAddDialog(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final relaysNotifier = ref.read(relaysProvider.notifier);
    bool isLoading = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.dark2,
              title: Text(
                S.of(context)!.addRelayDialogTitle,
                style: const TextStyle(color: AppTheme.cream1),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.addRelayDialogDescription,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    enabled: !isLoading,
                    style: const TextStyle(color: AppTheme.cream1),
                    decoration: InputDecoration(
                      labelText: S.of(context)!.addRelayDialogPlaceholder,
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      hintText: 'relay.example.com',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.textSecondary),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.cream1),
                      ),
                      errorText: errorMessage,
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    autofocus: true,
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cream1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          S.of(context)!.addRelayDialogTesting,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    S.of(context)!.addRelayDialogCancel,
                    style: TextStyle(
                      color: isLoading ? AppTheme.textSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final input = textController.text.trim();
                          if (input.isEmpty) return;

                          // Capture context values before async operations
                          final localizations = S.of(context)!;
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final result = await relaysNotifier.addRelayWithSmartValidation(
                              input,
                              errorOnlySecure: localizations.addRelayErrorOnlySecure,
                              errorNoHttp: localizations.addRelayErrorNoHttp,
                              errorInvalidDomain: localizations.addRelayErrorInvalidDomain,
                              errorAlreadyExists: localizations.addRelayErrorAlreadyExists,
                              errorNotValid: localizations.addRelayErrorNotValid,
                            );

                            if (result.success) {
                              navigator.pop();
                              if (context.mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      localizations.addRelaySuccessMessage(result.normalizedUrl!),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setState(() {
                                errorMessage = result.error;
                                isLoading = false;
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = localizations.addRelayErrorGeneric;
                              isLoading = false;
                            });
                          }
                        },
                  child: Text(
                    S.of(context)!.addRelayDialogAdd,
                    style: TextStyle(
                      color: isLoading ? AppTheme.textSecondary : AppTheme.cream1,
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