import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/features/mostro/widgets/add_custom_node_dialog.dart';
import 'package:mostro_mobile/features/mostro/widgets/mostro_node_avatar.dart';
import 'package:mostro_mobile/features/mostro/widgets/trusted_badge.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class MostroNodeSelector extends ConsumerStatefulWidget {
  const MostroNodeSelector({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MostroNodeSelector(),
    );
  }

  @override
  ConsumerState<MostroNodeSelector> createState() => _MostroNodeSelectorState();
}

class _MostroNodeSelectorState extends ConsumerState<MostroNodeSelector> {
  bool _isSwitching = false;
  String? _switchingPubkey;

  @override
  Widget build(BuildContext context) {
    ref.watch(mostroNodesProvider);
    final currentPubkey = ref.watch(settingsProvider).mostroPublicKey;
    final notifier = ref.read(mostroNodesProvider.notifier);
    final trustedNodes = notifier.trustedNodes;
    final customNodes = notifier.customNodes;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              S.of(context)!.selectMostroNode,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Node list
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trusted nodes section
                  if (trustedNodes.isNotEmpty) ...[
                    _buildSectionHeader(
                      S.of(context)!.trustedNodesSection,
                    ),
                    const SizedBox(height: 8),
                    ...trustedNodes.map(
                      (node) => _buildNodeItem(
                        node,
                        currentPubkey,
                        isCustom: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Custom nodes section
                  _buildSectionHeader(
                    S.of(context)!.customNodesSection,
                  ),
                  const SizedBox(height: 8),
                  if (customNodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        S.of(context)!.noCustomNodesYet,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ...customNodes.map(
                      (node) => _buildNodeItem(
                        node,
                        currentPubkey,
                        isCustom: true,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Add custom node button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _isSwitching
                            ? null
                            : () => AddCustomNodeDialog.show(context, ref),
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
                          S.of(context)!.addCustomNode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 16 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildNodeItem(
    MostroNode node,
    String currentPubkey, {
    required bool isCustom,
  }) {
    final isSelected = node.pubkey == currentPubkey;
    final isLoading = _switchingPubkey == node.pubkey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isSwitching || isSelected) ? null : () => _onNodeTap(node),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.activeColor.withValues(alpha: 0.1)
                  : AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.activeColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                MostroNodeAvatar(node: node),
                const SizedBox(width: 12),
                // Name + pubkey
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              node.displayName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (node.isTrusted) ...[
                            const SizedBox(width: 8),
                            const TrustedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.pubkey,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (node.about != null && node.about!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          node.about!.length > 128
                              ? '${node.about!.substring(0, 128)}...'
                              : node.about!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing: checkmark, loading, or delete
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.cream1),
                    ),
                  )
                else if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.activeColor,
                    size: 22,
                  )
                else if (isCustom)
                  IconButton(
                    onPressed: _isSwitching ? null : () => _onDeleteNode(node),
                    tooltip: S.of(context)!.deleteCustomNodeTitle,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onNodeTap(MostroNode node) async {
    setState(() {
      _isSwitching = true;
      _switchingPubkey = node.pubkey;
    });

    // Capture context values before async
    final messenger = ScaffoldMessenger.of(context);
    final mediaQuery = MediaQuery.of(context);
    final localizations = S.of(context)!;
    final navigator = Navigator.of(context);

    try {
      final notifier = ref.read(mostroNodesProvider.notifier);
      final oldPubkey = ref.read(settingsProvider).mostroPublicKey;

      await notifier.selectNode(node.pubkey);

      if (oldPubkey != node.pubkey) {
        try {
          final restoreService = ref.read(restoreServiceProvider);
          await restoreService.initRestoreProcess();
        } catch (_) {
          // Ignore errors during restore
        }
      }

      navigator.pop();

      SnackBarHelper.showTopSnackBarAsync(
        messenger: messenger,
        screenHeight: mediaQuery.size.height,
        statusBarHeight: mediaQuery.padding.top,
        message: localizations.nodeSwitchedSuccess(node.displayName),
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSwitching = false;
          _switchingPubkey = null;
        });
      }
      SnackBarHelper.showTopSnackBarAsync(
        messenger: messenger,
        screenHeight: mediaQuery.size.height,
        statusBarHeight: mediaQuery.padding.top,
        message: localizations.errorSwitchingNode,
      );
    }
  }

  Future<void> _onDeleteNode(MostroNode node) async {
    final localizations = S.of(context)!;
    final notifier = ref.read(mostroNodesProvider.notifier);
    final currentPubkey = ref.read(settingsProvider).mostroPublicKey;

    if (node.pubkey == currentPubkey) {
      SnackBarHelper.showTopSnackBar(
        context,
        localizations.cannotRemoveActiveNode,
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.dark2,
        title: Text(
          localizations.deleteCustomNodeTitle,
          style: const TextStyle(color: AppTheme.cream1),
        ),
        content: Text(
          localizations.deleteCustomNodeMessage,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              localizations.deleteCustomNodeCancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              localizations.deleteCustomNodeConfirm,
              style: const TextStyle(color: AppTheme.red1),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final removed = await notifier.removeCustomNode(node.pubkey);
      if (!mounted) return;
      if (removed) {
        SnackBarHelper.showTopSnackBar(
          context,
          localizations.nodeRemovedSuccess,
        );
      } else {
        SnackBarHelper.showTopSnackBar(
          context,
          localizations.nodeRemoveFailed,
        );
      }
    }
  }
}
