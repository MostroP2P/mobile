import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileState()) {
    on<LoadProfile>(_onLoadProfile);
  }

  void _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) {
    emit(state.copyWith(status: ProfileStatus.loading));

    // Simulamos la carga del perfil con datos hardcodeados
    Future.delayed(const Duration(seconds: 1), () {
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        username: 'SatoshiNakamoto',
        pubkey:
            'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3xvmkv',
        completedTrades: 42,
        rating: 4.8,
      ));
    });
  }
}
