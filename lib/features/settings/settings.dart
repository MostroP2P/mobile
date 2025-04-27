class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroPublicKey;
  final String? defaultFiatCode;

  Settings({
    required this.relays,
    required this.fullPrivacyMode,
    required this.mostroPublicKey,
    this.defaultFiatCode,
  });

  Settings copyWith({
    List<String>? relays,
    bool? privacyModeSetting,
    String? mostroInstance,
    String? defaultFiatCode,
  }) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: privacyModeSetting ?? fullPrivacyMode,
      mostroPublicKey: mostroInstance ?? mostroPublicKey,
      defaultFiatCode: defaultFiatCode ?? this.defaultFiatCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroPublicKey': mostroPublicKey,
        'defaultFiatCode': defaultFiatCode,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroPublicKey: json['mostroPublicKey'],
      defaultFiatCode: json['defaultFiatCode'],
    );
  }
}
