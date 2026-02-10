import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class AddCustomNodeDialog {

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final pubkeyController = TextEditingController();
    final nameController = TextEditingController();
    String? errorMessage;

    // Capture parent context values before entering dialog
    final parentMessenger = ScaffoldMessenger.of(context);
    final parentMediaQuery = MediaQuery.of(context);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (builderContext, setState) {
              return AlertDialog(
                backgroundColor: AppTheme.backgroundCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                title: Text(
                  S.of(builderContext)!.addCustomNodeTitle,
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
                      // Pubkey input
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: pubkeyController,
                          style:
                              const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText:
                                S.of(builderContext)!.enterNodePubkey,
                            labelStyle: const TextStyle(
                                color: AppTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: S.of(builderContext)!.pubkeyHint,
                            hintStyle: const TextStyle(
                                color: AppTheme.textSecondary),
                            errorText: errorMessage,
                            errorStyle:
                                const TextStyle(color: Colors.red),
                          ),
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Name input
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: nameController,
                          style:
                              const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText:
                                S.of(builderContext)!.enterNodeName,
                            labelStyle: const TextStyle(
                                color: AppTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: S.of(builderContext)!.nodeNameHint,
                            hintStyle: const TextStyle(
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      S.of(builderContext)!.cancel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final input = pubkeyController.text.trim();
                      final name = nameController.text.trim();
                      final localizations = S.of(builderContext)!;
                      final navigator = Navigator.of(dialogContext);

                      if (input.isEmpty) {
                        setState(() {
                          errorMessage = localizations.pubkeyRequired;
                        });
                        return;
                      }

                      // Reject nsec private keys
                      if (input.startsWith('nsec')) {
                        setState(() {
                          errorMessage =
                              localizations.invalidPubkeyFormat;
                        });
                        return;
                      }

                      // Convert npub to hex if needed
                      String hexPubkey;
                      try {
                        hexPubkey = _convertToHex(input);
                      } catch (_) {
                        setState(() {
                          errorMessage =
                              localizations.invalidPubkeyFormat;
                        });
                        return;
                      }

                      // Validate hex format
                      if (!MostroNode.isValidHexPubkey(hexPubkey)) {
                        setState(() {
                          errorMessage =
                              localizations.invalidPubkeyFormat;
                        });
                        return;
                      }

                      // Check duplicates
                      final nodes = ref.read(mostroNodesProvider);
                      if (nodes.any((n) => n.pubkey == hexPubkey)) {
                        setState(() {
                          errorMessage =
                              localizations.nodeAlreadyExists;
                        });
                        return;
                      }

                      final notifier =
                          ref.read(mostroNodesProvider.notifier);
                      final added = await notifier.addCustomNode(
                        hexPubkey,
                        name: name.isEmpty ? null : name,
                      );

                      if (added) {
                        // Fire-and-forget: errors are logged inside fetchNodeMetadata
                        unawaited(notifier.fetchNodeMetadata(hexPubkey));

                        navigator.pop();
                        SnackBarHelper.showTopSnackBarAsync(
                          messenger: parentMessenger,
                          screenHeight:
                              parentMediaQuery.size.height,
                          statusBarHeight:
                              parentMediaQuery.padding.top,
                          message: localizations.nodeAddedSuccess,
                          backgroundColor: Colors.green,
                        );
                      } else {
                        setState(() {
                          errorMessage =
                              localizations.nodeAlreadyExists;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.activeColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      S.of(builderContext)!.addCustomNode,
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
    } finally {
      pubkeyController.dispose();
      nameController.dispose();
    }
  }

  static String _convertToHex(String input) {
    if (input.startsWith('npub1')) {
      return NostrUtils.decodeBech32(input);
    }
    return input;
  }
}
