import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/trade_history_restoration_service.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

final tradeHistoryRestorationProvider = Provider<TradeHistoryRestorationService>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final nostrService = ref.read(nostrServiceProvider);

  return TradeHistoryRestorationService(
    keyManager,
    nostrService,
  );
});
