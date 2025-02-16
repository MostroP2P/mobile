import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrProvider = Provider<NostrService>((ref) {
  throw UnimplementedError();
});

final nostrServicerProvider = Provider<NostrService>((ref) {
  final service = ref.watch(nostrProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    service.updateSettings(next);
  });

  return service;
});

