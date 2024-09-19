import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class RegisterRequested extends AuthEvent {
  final String nsec;
  final String password;

  RegisterRequested(this.nsec, this.password);

  @override
  List<Object> get props => [nsec, password];
}

class LoginRequested extends AuthEvent {
  final String password;

  LoginRequested(this.password);

  @override
  List<Object> get props => [password];
}

class DeleteAccountRequested extends AuthEvent {}
