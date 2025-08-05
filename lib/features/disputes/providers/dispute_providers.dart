import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';
import 'package:mostro_mobile/data/repositories/dispute_repository.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

/// Provider for the dispute repository
final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  final nostrService = ref.read(nostrServiceProvider);
  final settings = ref.read(settingsProvider);
  final mostroPubkey = settings.mostroPublicKey;
  
  return DisputeRepository(nostrService, mostroPubkey);
});

/// Provider that fetches all user disputes
final userDisputesProvider = FutureProvider<List<DisputeEvent>>((ref) async {
  final repository = ref.read(disputeRepositoryProvider);
  return repository.fetchUserDisputes();
});

/// Provider that fetches details for a specific dispute
final disputeDetailsProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  final repository = ref.read(disputeRepositoryProvider);
  return repository.getDisputeDetails(disputeId);
});

/// Provider for dispute events stream (simplified for now)
final disputeEventsStreamProvider = StreamProvider<DisputeEvent>((ref) {
  final repository = ref.read(disputeRepositoryProvider);
  return repository.subscribeToDisputeEvents();
});
