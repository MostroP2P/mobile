import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/config/communities.dart';
import 'package:mostro_mobile/features/community/community.dart';
import 'package:mostro_mobile/features/community/providers/community_selector_provider.dart';
import 'package:mostro_mobile/features/community/widgets/community_card.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/features/mostro/widgets/add_custom_node_dialog.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class CommunitySelectorScreen extends ConsumerStatefulWidget {
  const CommunitySelectorScreen({super.key});

  @override
  ConsumerState<CommunitySelectorScreen> createState() =>
      _CommunitySelectorScreenState();
}

class _CommunitySelectorScreenState
    extends ConsumerState<CommunitySelectorScreen> {
  String? _selectedPubkey;
  String _searchQuery = '';
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(communityListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt,
                    color: AppTheme.activeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.chooseYourCommunity,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    icon: const Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    hintText: S.of(context)!.communitySearchHint,
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 16),
              // Community list
              Expanded(
                child: communitiesAsync.when(
                  loading: () => _buildLoadingSkeleton(),
                  error: (error, _) => _buildErrorState(context),
                  data: (communities) {
                    final filtered = _filterCommunities(communities);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          S.of(context)!.noCommunityResults,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final community = filtered[index];
                        return CommunityCard(
                          community: community,
                          isSelected: _selectedPubkey == community.pubkey,
                          onTap: () => setState(
                            () => _selectedPubkey = community.pubkey,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Use custom node
              TextButton(
                onPressed: _isSelecting
                    ? null
                    : () => _onUseCustomNode(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.settings,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context)!.useCustomNode,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Confirm button
              if (_selectedPubkey != null)
                ElevatedButton(
                  onPressed: _isSelecting ? null : () => _onConfirm(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.activeColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSelecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          S.of(context)!.done,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              // Skip button
              TextButton(
                onPressed: _isSelecting ? null : () => _onSkip(context),
                child: Text(
                  S.of(context)!.skipForNow,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).viewPadding.bottom + 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Community> _filterCommunities(List<Community> communities) {
    if (_searchQuery.isEmpty) return communities;
    final query = _searchQuery.toLowerCase();
    return communities.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.region.toLowerCase().contains(query) ||
          c.currencies.any((cur) => cur.toLowerCase().contains(query)) ||
          (c.about?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: trustedCommunities.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            color: AppTheme.textSecondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.communityLoadingError,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(communityListProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.activeColor,
              foregroundColor: Colors.black,
            ),
            child: Text(S.of(context)!.communityRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm(BuildContext context) async {
    if (_selectedPubkey == null) return;
    setState(() => _isSelecting = true);

    try {
      await _selectAndProceed(_selectedPubkey!);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  Future<void> _onSkip(BuildContext context) async {
    setState(() => _isSelecting = true);
    try {
      await _selectAndProceed(defaultMostroPubkey);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  Future<void> _onUseCustomNode(BuildContext context) async {
    final pubkeysBefore =
        ref.read(mostroNodesProvider).map((n) => n.pubkey).toSet();
    await AddCustomNodeDialog.show(context, ref);
    if (!mounted) return;

    // Detect newly added node via set difference
    final pubkeysAfter =
        ref.read(mostroNodesProvider).map((n) => n.pubkey).toSet();
    final newPubkeys = pubkeysAfter.difference(pubkeysBefore);
    if (newPubkeys.isNotEmpty) {
      setState(() => _isSelecting = true);
      try {
        await _selectAndProceed(newPubkeys.first);
      } finally {
        if (mounted) setState(() => _isSelecting = false);
      }
    }
  }

  Future<void> _selectAndProceed(String pubkey) async {
    // Ensure the pubkey exists as a node
    await _ensureNodeExists(pubkey);

    // Select the node
    final nodesNotifier = ref.read(mostroNodesProvider.notifier);
    await nodesNotifier.selectNode(pubkey);

    // Mark community as selected
    await ref
        .read(communitySelectedProvider.notifier)
        .markCommunitySelected();

    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _ensureNodeExists(String pubkey) async {
    final allNodes = ref.read(mostroNodesProvider);
    if (allNodes.any((n) => n.pubkey == pubkey)) return;

    final notifier = ref.read(mostroNodesProvider.notifier);
    await notifier.addCustomNode(pubkey);
  }
}
