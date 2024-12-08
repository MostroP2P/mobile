import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_notifier.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_state.dart';


final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    biometricsHelper: ref.read(biometricsHelperProvider),
  ),
);

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

final isFirstLaunchProvider = Provider<bool>((ref) => false);

final biometricsHelperProvider = Provider<BiometricsHelper>((ref) {
  throw UnimplementedError();
});

final navigatorKeyProvider =
    Provider<GlobalKey<NavigatorState>>((ref) => GlobalKey<NavigatorState>());
