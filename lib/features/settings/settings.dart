class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroPublicKey;
  final String? defaultFiatCode;
  final String? selectedLanguage; // null means use system locale
  final String? defaultLightningAddress;
  final List<String> blacklistedRelays; // Relays blocked by user from auto-sync
  final List<Map<String, dynamic>> userRelays; // User-added relays with metadata
  final String? customLogStorageDirectory; // Custom directory for log exports

  Settings({
    required this.relays,
    required this.fullPrivacyMode,
    required this.mostroPublicKey,
    this.defaultFiatCode,
    this.selectedLanguage,
    this.defaultLightningAddress,
    this.blacklistedRelays = const [],
    this.userRelays = const [],
    this.customLogStorageDirectory,
  });

  Settings copyWith({
    List<String>? relays,
    bool? privacyModeSetting,
    String? mostroPublicKey,
    String? defaultFiatCode,
    String? selectedLanguage,
    String? defaultLightningAddress,
    bool clearDefaultLightningAddress = false,
    List<String>? blacklistedRelays,
    List<Map<String, dynamic>>? userRelays,
    String? customLogStorageDirectory,
  }) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: privacyModeSetting ?? fullPrivacyMode,
      mostroPublicKey: mostroPublicKey ?? this.mostroPublicKey,
      defaultFiatCode: defaultFiatCode ?? this.defaultFiatCode,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      defaultLightningAddress: clearDefaultLightningAddress
          ? null
          : (defaultLightningAddress ?? this.defaultLightningAddress),
      blacklistedRelays: blacklistedRelays ?? this.blacklistedRelays,
      userRelays: userRelays ?? this.userRelays,
      customLogStorageDirectory: customLogStorageDirectory ?? this.customLogStorageDirectory,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroPublicKey': mostroPublicKey,
        'defaultFiatCode': defaultFiatCode,
        'selectedLanguage': selectedLanguage,
        'defaultLightningAddress': defaultLightningAddress,
        'blacklistedRelays': blacklistedRelays,
        'userRelays': userRelays,
        'customLogStorageDirectory': customLogStorageDirectory,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroPublicKey: json['mostroPublicKey'],
      defaultFiatCode: json['defaultFiatCode'],
      selectedLanguage: json['selectedLanguage'],
      defaultLightningAddress: json['defaultLightningAddress'],
      blacklistedRelays: (json['blacklistedRelays'] as List<dynamic>?)?.cast<String>() ?? [],
      userRelays: (json['userRelays'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [],
      customLogStorageDirectory: json['customLogStorageDirectory'],
    );
  }
}
