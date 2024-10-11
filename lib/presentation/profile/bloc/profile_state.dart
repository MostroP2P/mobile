import 'package:equatable/equatable.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final String username;
  final String pubkey;
  final int completedTrades;
  final double rating;
  final String errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.username = '',
    this.pubkey = '',
    this.completedTrades = 0,
    this.rating = 0.0,
    this.errorMessage = '',
  });

  ProfileState copyWith({
    ProfileStatus? status,
    String? username,
    String? pubkey,
    int? completedTrades,
    double? rating,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      username: username ?? this.username,
      pubkey: pubkey ?? this.pubkey,
      completedTrades: completedTrades ?? this.completedTrades,
      rating: rating ?? this.rating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object> get props =>
      [status, username, pubkey, completedTrades, rating, errorMessage];
}
