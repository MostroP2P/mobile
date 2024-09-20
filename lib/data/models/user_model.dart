class User {
  final String publicKey;

  User({required this.publicKey});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      publicKey: json['publicKey'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publicKey': publicKey,
    };
  }
}
