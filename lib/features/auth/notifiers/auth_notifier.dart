import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository authRepository;

  AuthNotifier(this.authRepository) : super(AuthInitial());

  Future<void> checkAuth() async {
    state = AuthLoading();
    try {
      final isRegistered = await authRepository.isRegistered();
      if (isRegistered) {
        state = AuthUnauthenticated();
      } else {
        state = AuthUnregistered();
      }
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> register({
    required String privateKey,
    required String password,
    required bool useBiometrics,
  }) async {
    state = AuthLoading();
    try {
      if (privateKey.startsWith('nsec')) {
        privateKey = NostrUtils.decodeNsecKeyToPrivateKey(privateKey);
      }
      await authRepository.register(privateKey, password, useBiometrics);
      state = AuthRegistrationSuccess();
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> login({required String password}) async {
    state = AuthLoading();
    try {
      final isAuthenticated = await authRepository.login(password);
      if (isAuthenticated) {
        state = AuthAuthenticated();
      } else {
        state = const AuthFailure(
            'Invalid PIN or biometric authentication failed');
      }
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    try {
      await authRepository.logout();
      state = AuthUnregistered();
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> generateKey() async {
    try {
      final newPrivateKey = await authRepository.generateNewIdentity();
      state = AuthKeyGenerated(NostrUtils.encodePrivateKeyToNsec(newPrivateKey));
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> checkBiometrics() async {
    try {
      final isAvailable = await authRepository.isBiometricsAvailable();
      state = AuthBiometricsAvailability(isAvailable);
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }
}
