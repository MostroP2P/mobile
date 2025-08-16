class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroPublicKey;
  final String? defaultFiatCode;
  final String? selectedLanguage; // null means use system locale
  final String? defaultLightningAddress;

  Settings({
    required this.relays,
    required this.fullPrivacyMode,
    required this.mostroPublicKey,
    this.defaultFiatCode,
    this.selectedLanguage,
    this.defaultLightningAddress,
  });

  Settings copyWith({
    List<String>? relays,
    bool? fullPrivacyMode,
    String? mostroPublicKey,
    String? defaultFiatCode,
    String? selectedLanguage,
    String? defaultLightningAddress,
  }) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: fullPrivacyMode ?? this.fullPrivacyMode,
      mostroPublicKey: mostroPublicKey ?? this.mostroPublicKey,
      defaultFiatCode: defaultFiatCode ?? this.defaultFiatCode,
      selectedLanguage: selectedLanguage,
      defaultLightningAddress: defaultLightningAddress,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroPublicKey': mostroPublicKey,
        'defaultFiatCode': defaultFiatCode,
        'selectedLanguage': selectedLanguage,
        'defaultLightningAddress': defaultLightningAddress,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroPublicKey: json['mostroPublicKey'],
      defaultFiatCode: json['defaultFiatCode'],
      selectedLanguage: json['selectedLanguage'],
      defaultLightningAddress: json['defaultLightningAddress'],
    );
  }
}
