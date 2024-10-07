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

  const AuthRegisterRequested(this.privateKey, this.password);

  @override
  List<Object> get props => [privateKey, password];
}

class AuthLoginRequested extends AuthEvent {
  final String password;

  const AuthLoginRequested(this.password);

  @override
  List<Object> get props => [password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthGenerateKeyRequested extends AuthEvent {}
