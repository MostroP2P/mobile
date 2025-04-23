import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
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
  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  final mostroService = MostroService(
    sessionNotifier,
    ref,
  );
  return mostroService;
}
