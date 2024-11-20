import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_bloc.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrServicerProvider = Provider<NostrService>((ref) {
  return NostrService()..init();
});

final homeBlocProvider = Provider<HomeBloc>((ref) {
  return HomeBloc();
});

final sessionManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.watch(sessionManagerProvider);
  final nostrService = ref.watch(nostrServicerProvider);
  return MostroService(nostrService, sessionStorage);
});

