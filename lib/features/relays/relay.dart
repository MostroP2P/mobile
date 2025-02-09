class Relay {
  final String url;
  bool isHealthy;

  Relay({
    required this.url,
    this.isHealthy = false,
  });

  Relay copyWith({String? url, bool? isHealthy}) {
    return Relay(
      url: url ?? this.url,
      isHealthy: isHealthy ?? this.isHealthy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'isHealthy': isHealthy,
    };
  }

  factory Relay.fromJson(Map<String, dynamic> json) {
    return Relay(
      url: json['url'] as String,
      isHealthy: json['isHealthy'] as bool? ?? false,
    );
  }
}
