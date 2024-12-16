import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

final sessionManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.watch(sessionManagerProvider);
  final nostrService = ref.watch(nostrServicerProvider);
  return MostroService(nostrService, sessionStorage);
});

final mostroRepositoryProvider = Provider<MostroRepository>((ref) {
  final mostroService = ref.watch(mostroServiceProvider);
  final openOrdersRepository = ref.watch(orderRepositoryProvider);
  return MostroRepository(mostroService, openOrdersRepository);
});
