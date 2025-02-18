import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrServiceProvider = Provider<NostrService>((ref) {
  return NostrService();
});
