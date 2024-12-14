import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthUnregistered extends AuthState {}

class AuthKeyGenerated extends AuthState {
  final String privateKey;

  const AuthKeyGenerated(this.privateKey);

  @override
  List<Object> get props => [privateKey];
}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure(this.error);

  @override
  List<Object> get props => [error];
}

class AuthBiometricsAvailability extends AuthState {
  final bool isAvailable;

  const AuthBiometricsAvailability(this.isAvailable);

  @override
  List<Object> get props => [isAvailable];
}

class AuthRegistrationSuccess extends AuthState {}
