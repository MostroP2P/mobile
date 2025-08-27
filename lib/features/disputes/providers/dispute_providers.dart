import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/repositories/dispute_repository.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

/// Provider for the dispute repository
final disputeRepositoryProvider = Provider.autoDispose<DisputeRepository>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final settings = ref.watch(settingsProvider);
  final mostroPubkey = settings.mostroPublicKey;
  
  final repository = DisputeRepository(nostrService, mostroPubkey, ref);
  
  // Register cleanup when provider is disposed
  ref.onDispose(() {
    // No explicit cleanup method in DisputeRepository, but we can add null safety
    // for future implementations
  });
  
  return repository;
});

/// Provider that fetches all user disputes
final userDisputesProvider = FutureProvider.autoDispose<List<Dispute>>((ref) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.fetchUserDisputes();
});

/// Provider that fetches details for a specific dispute
final disputeDetailsProvider = FutureProvider.autoDispose.family<Dispute?, String>((ref, disputeId) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.getDisputeDetails(disputeId);
});

/// Provider for dispute events stream (simplified for now)
final disputeEventsStreamProvider = StreamProvider.autoDispose<Dispute>((ref) {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.subscribeToDisputeEvents();
});

/// Provider for creating a new dispute
final createDisputeProvider = FutureProvider.autoDispose.family<bool, String>((ref, orderId) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.createDispute(orderId);
});
