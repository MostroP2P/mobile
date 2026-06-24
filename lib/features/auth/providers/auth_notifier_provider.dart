import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_notifier.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';

final biometricsHelperProvider = Provider<BiometricsHelper>((ref) {
  throw UnimplementedError();
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    biometricsHelper: ref.read(biometricsHelperProvider),
  ),
);

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

final obscurePrivateKeyProvider = StateProvider<bool>((ref) => true);
final obscurePinProvider = StateProvider<bool>((ref) => true);
final obscureConfirmPinProvider = StateProvider<bool>((ref) => true);
final useBiometricsProvider = StateProvider<bool>((ref) => false);
