import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrServicerProvider = Provider<NostrService>((ref) {
  return NostrService();
});
