import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class NostrServiceNotifier extends AsyncNotifier<NostrService> {
  @override
  Future<NostrService> build() async {
    final service = NostrService();
    await service.init();
    return service;
  }
}

final nostrServiceProvider = Provider<NostrService>((ref) {
  return NostrService()..init();
});