import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/services/event_bus.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'mostro_service_provider.g.dart';

@riverpod
EventStorage eventStorage(Ref ref) {
  final db = ref.watch(mostroDatabaseProvider);
  return EventStorage(db: db);
}

@riverpod
MostroService mostroService(Ref ref) {
  final sessionStorage = ref.read(sessionNotifierProvider.notifier);
  final eventStore = ref.read(eventStorageProvider);
  final eventBus = ref.read(eventBusProvider);
  final mostroDatabase = ref.read(mostroStorageProvider);
  final backgroundService = ref.read(backgroundServiceProvider);
  final mostroService = MostroService(
    sessionStorage,
    eventStore,
    eventBus,
    mostroDatabase,
    ref,
    backgroundService,
  );
  return mostroService;
}
