import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrServiceProvider = Provider<NostrService>((ref) {
  final settings = ref.read(settingsProvider);
  final nostrService = NostrService(settings);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    nostrService.updateSettings(next);
  });

  return nostrService;
});
