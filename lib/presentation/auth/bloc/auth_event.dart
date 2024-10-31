import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthRegisterRequested extends AuthEvent {
  final String privateKey;
  final String password;
  final bool useBiometrics;

  const AuthRegisterRequested(this.privateKey, this.password, this.useBiometrics);

  @override
  List<Object> get props => [privateKey, password, useBiometrics];
}

class AuthLoginRequested extends AuthEvent {
  final String password;

  const AuthLoginRequested(this.password);

  @override
  List<Object> get props => [password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthGenerateKeyRequested extends AuthEvent {}

class AuthCheckBiometricsRequested extends AuthEvent {}