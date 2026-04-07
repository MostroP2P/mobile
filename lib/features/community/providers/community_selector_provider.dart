import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config/communities.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/repositories/community_repository.dart';
import 'package:mostro_mobile/features/community/community.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has already selected a community.
final communitySelectedProvider =
    StateNotifierProvider<CommunitySelectedNotifier, AsyncValue<bool>>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return CommunitySelectedNotifier(prefs);
});

class CommunitySelectedNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesAsync _prefs;

  CommunitySelectedNotifier(this._prefs) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final selected = await _prefs.getBool(
        SharedPreferencesKeys.communitySelected.value,
      );
      if (selected == true) {
        if (!mounted) return;
        state = const AsyncValue.data(true);
        return;
      }

      // Backward compatibility: existing users who completed onboarding
      // before community selector existed should not be interrupted.
      final firstRunComplete = await _prefs.getBool(
        SharedPreferencesKeys.firstRunComplete.value,
      );
      if (firstRunComplete == true) {
        // Auto-mark as selected so existing users are not interrupted
        await _prefs.setBool(
          SharedPreferencesKeys.communitySelected.value,
          true,
        );
        if (!mounted) return;
        state = const AsyncValue.data(true);
        return;
      }

      if (!mounted) return;
      state = const AsyncValue.data(false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> markCommunitySelected() async {
    try {
      await _prefs.setBool(
        SharedPreferencesKeys.communitySelected.value,
        true,
      );
      if (!mounted) return;
      state = const AsyncValue.data(true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Provides the CommunityRepository instance.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

/// Fetches community data from Nostr relays. Returns enriched Community list.
final communityListProvider = FutureProvider<List<Community>>((ref) async {
  // Start with static config
  final communities =
      trustedCommunities.map((c) => Community.fromConfig(c)).toList();

  // Fetch metadata from Nostr via repository
  final repository = ref.read(communityRepositoryProvider);
  final pubkeys = communities.map((c) => c.pubkey).toList();
  final metadata = await repository.fetchCommunityMetadata(pubkeys);

  // Enrich communities with fetched data
  return communities.map((community) {
    final meta = metadata[community.pubkey];
    if (meta == null) return community;

    return community.copyWith(
      name: meta.name,
      about: meta.about,
      picture: meta.picture,
      hasTradeInfo: meta.hasTradeInfo,
      currencies: meta.currencies,
      minAmount: meta.minAmount,
      maxAmount: meta.maxAmount,
      fee: meta.fee,
    );
  }).toList();
});
