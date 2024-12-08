import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../shared/utils/nostr_utils.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthGenerateKeyRequested>(_onAuthGenerateKeyRequested);
    on<AuthCheckBiometricsRequested>(_onAuthCheckBiometricsRequested);
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final isRegistered = await authRepository.isRegistered();
    if (isRegistered) {
      emit(AuthUnauthenticated());
    } else {
      emit(AuthUnregistered());
    }
  }

  Future<void> _onAuthRegisterRequested(
      AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      String privateKey = event.privateKey;
      if (privateKey.startsWith('nsec')) {
        privateKey = NostrUtils.decodeNsecKeyToPrivateKey(privateKey);
      }
      await authRepository.register(
          privateKey, event.password, event.useBiometrics);
      emit(AuthRegistrationSuccess());
    } catch (e, stackTrace) {
      print('Error during registration: $e');
      print('Stack trace: $stackTrace');
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final isAuthenticated = await authRepository.login(event.password);
      if (isAuthenticated) {
        emit(AuthAuthenticated());
      } else {
        emit(const AuthFailure(
            'Invalid PIN or biometric authentication failed'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(AuthUnregistered());
  }

  Future<void> _onAuthGenerateKeyRequested(
      AuthGenerateKeyRequested event, Emitter<AuthState> emit) async {
    final newPrivateKey = await authRepository.generateNewIdentity();
    emit(AuthKeyGenerated(NostrUtils.encodePrivateKeyToNsec(newPrivateKey)));
  }

  Future<void> _onAuthCheckBiometricsRequested(
      AuthCheckBiometricsRequested event, Emitter<AuthState> emit) async {
    final isAvailable = await authRepository.isBiometricsAvailable();
    emit(AuthBiometricsAvailability(isAvailable));
  }
}
