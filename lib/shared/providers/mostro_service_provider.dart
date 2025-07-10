import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mostro_service_provider.g.dart';

@Riverpod(keepAlive: true)
EventStorage eventStorage(Ref ref) {
  final db = ref.watch(eventDatabaseProvider);
  return EventStorage(db: db);
}

@Riverpod(keepAlive: true)
MostroService mostroService(Ref ref) {
  final mostroService = MostroService(ref);
  mostroService.init();
  
  ref.listen(settingsProvider, (previous, next) {
    mostroService.updateSettings(next);
  });
  
  ref.onDispose(() {
    mostroService.dispose();
  });
  
  return mostroService;
}
