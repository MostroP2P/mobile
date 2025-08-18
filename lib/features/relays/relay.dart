/// Represents the source of a relay configuration
enum RelaySource {
  /// User manually added this relay
  user,
  /// Relay discovered from Mostro instance kind 10002 event
  mostro,
  /// Default relay from app configuration
  defaultConfig,
}

class Relay {
  final String url;
  bool isHealthy;
  final RelaySource source;
  final DateTime? addedAt;

  Relay({
    required this.url,
    this.isHealthy = true,
    this.source = RelaySource.user,
    this.addedAt,
  });

  Relay copyWith({
    String? url,
    bool? isHealthy,
    RelaySource? source,
    DateTime? addedAt,
  }) {
    return Relay(
      url: url ?? this.url,
      isHealthy: isHealthy ?? this.isHealthy,
      source: source ?? this.source,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'isHealthy': isHealthy,
      'source': source.name,
      'addedAt': addedAt?.millisecondsSinceEpoch,
    };
  }

  factory Relay.fromJson(Map<String, dynamic> json) {
    return Relay(
      url: json['url'] as String,
      isHealthy: json['isHealthy'] as bool? ?? false,
      source: RelaySource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => RelaySource.user,
      ),
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int)
          : null,
    );
  }

  /// Creates a relay from a Mostro instance discovery
  factory Relay.fromMostro(String url) {
    return Relay(
      url: url,
      isHealthy: true,
      source: RelaySource.mostro,
      addedAt: DateTime.now(),
    );
  }

  /// Creates a relay from default configuration
  factory Relay.fromDefault(String url) {
    return Relay(
      url: url,
      isHealthy: true,
      source: RelaySource.defaultConfig,
      addedAt: DateTime.now(),
    );
  }

  /// Whether this relay was automatically discovered
  bool get isAutoDiscovered => source == RelaySource.mostro || source == RelaySource.defaultConfig;

  /// Whether this relay can be deleted by the user
  bool get canDelete => source == RelaySource.user;

  /// Whether this relay can be blacklisted (Mostro and default relays)
  bool get canBlacklist => source == RelaySource.mostro || source == RelaySource.defaultConfig;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Relay && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() {
    return 'Relay(url: $url, healthy: $isHealthy, source: $source)';
  }
}
