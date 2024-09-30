import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../core/utils/nostr_utils.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      emit(AuthLoading());
      final isRegistered = await authRepository.isRegistered();
      if (isRegistered) {
        emit(AuthUnauthenticated());
      } else {
        emit(AuthUnregistered());
      }
    });

    on<AuthRegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.register(event.privateKey, event.password);
        emit(AuthAuthenticated());
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final isAuthenticated = await authRepository.login(event.password);
        if (isAuthenticated) {
          emit(AuthAuthenticated());
        } else {
          emit(AuthFailure('Invalid password'));
        }
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    on<AuthLogoutRequested>((event, emit) async {
      emit(AuthLoading());
      await authRepository.logout();
      emit(AuthUnregistered());
    });

    on<AuthGenerateKeyRequested>((event, emit) {
      final newPrivateKey = NostrUtils.generatePrivateKey();
      emit(AuthKeyGenerated(newPrivateKey));
    });
  }
}
