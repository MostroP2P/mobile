import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/relay.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';
import 'package:mostro_mobile/shared/widgets/mostro_switch.dart';

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
          // Status dot - green if active, grey if inactive
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: relayInfo.isActive ? AppTheme.activeColor : Colors.grey,
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
          
          // Control - Switch for Mostro/default relays, Delete button for user relays
          relayInfo.source == RelaySource.user
              ? _buildDeleteButton(context, ref, relayInfo)
              : _buildRelaySwitch(context, ref, relayInfo),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) {
    return Container(
      width: 140,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () async {
              await _showDeleteUserRelayDialog(context, ref, relayInfo);
            },
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaySwitch(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) {
    return MostroSwitch(
      value: relayInfo.isActive,
      onChanged: (value) async {
        await _handleRelayToggle(context, ref, relayInfo);
      },
    );
  }

  /// Show confirmation dialog for deleting user relay
  Future<void> _showDeleteUserRelayDialog(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) async {
    final relaysNotifier = ref.read(relaysProvider.notifier);
    
    // Check if this would leave no active relays
    if (relaysNotifier.wouldLeaveNoActiveRelays(relayInfo.url)) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.dark2,
          title: Text(
            S.of(ctx)!.cannotBlacklistLastRelayTitle,
            style: const TextStyle(color: AppTheme.cream1),
          ),
          content: Text(
            S.of(ctx)!.cannotBlacklistLastRelayMessage,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                S.of(ctx)!.cannotBlacklistLastRelayOk,
                style: const TextStyle(color: AppTheme.cream1),
              ),
            ),
          ],
        ),
      );
      return; // Exit early - don't proceed with deletion
    }
    
    // If not the last relay, show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.dark2,
          title: Text(
            S.of(context)!.deleteUserRelayTitle,
            style: const TextStyle(color: AppTheme.cream1),
          ),
          content: Text(
            S.of(context)!.deleteUserRelayMessage,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                S.of(context)!.deleteUserRelayCancel,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                S.of(context)!.deleteUserRelayConfirm,
                style: const TextStyle(color: AppTheme.activeColor),
              ),
            ),
          ],
        );
      },
    );

    // If user confirmed deletion, remove the relay
    if (shouldDelete == true) {
      await relaysNotifier.removeRelay(relayInfo.url);
    }
  }

  /// Handle relay toggle with safety checks and confirmation dialogs
  Future<void> _handleRelayToggle(BuildContext context, WidgetRef ref, MostroRelayInfo relayInfo) async {
    final isCurrentlyBlacklisted = !relayInfo.isActive;
    final isDefaultMostroRelay = relayInfo.url.startsWith('wss://relay.mostro.network');
    final relaysNotifier = ref.read(relaysProvider.notifier);
    
    // Detect relay type (user vs mostro/default)
    final currentRelays = ref.read(relaysProvider);
    final relay = currentRelays.firstWhere(
      (r) => r.url == relayInfo.url, 
      orElse: () => Relay(url: ''), // Empty relay if not found
    );
    final isUserRelay = relay.url.isNotEmpty && relay.source == RelaySource.user;
    
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
    
    // Handle deactivation based on relay type
    if (isUserRelay) {
      // User relay: Delete completely (no blacklisting needed)
      await relaysNotifier.removeRelay(relayInfo.url);
    } else if (isDefaultMostroRelay) {
      // Default relay: Show confirmation dialog before blacklisting
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
      // Regular Mostro relay - proceed directly with blacklisting
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
              backgroundColor: AppTheme.backgroundCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              title: Text(
                S.of(context)!.addRelayDialogTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: textController,
                      enabled: !isLoading,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: S.of(context)!.addRelayDialogPlaceholder,
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: 'relay.example.com or wss://relay.example.com',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        errorText: errorMessage,
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                      autofocus: true,
                    ),
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
              ),
              actions: [
                if (!isLoading) ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      S.of(context)!.addRelayDialogCancel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final input = textController.text.trim();
                          if (input.isEmpty) return;

                          // Capture context values before async operations
                          final localizations = S.of(context)!;
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
                                SnackBarHelper.showTopSnackBar(
                                  context,
                                  localizations.addRelaySuccessMessage(result.normalizedUrl!),
                                  backgroundColor: AppTheme.mostroGreen,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.activeColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(
                    S.of(context)!.addRelayDialogAdd,
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
      },
    );
  }
}