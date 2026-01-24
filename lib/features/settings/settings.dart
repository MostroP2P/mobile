class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroPublicKey;
  final String? defaultFiatCode;
  final String? selectedLanguage; // null means use system locale
  final String? defaultLightningAddress;
  final List<String> blacklistedRelays;
  final List<Map<String, dynamic>> userRelays;
  final bool isLoggingEnabled;
  // Push notification settings
  final bool pushNotificationsEnabled;
  final bool notificationSoundEnabled;
  final bool notificationVibrationEnabled;

  Settings({
    required this.relays,
    required this.fullPrivacyMode,
    required this.mostroPublicKey,
    this.defaultFiatCode,
    this.selectedLanguage,
    this.defaultLightningAddress,
    this.blacklistedRelays = const [],
    this.userRelays = const [],
    this.isLoggingEnabled = false,
    this.pushNotificationsEnabled = true,
    this.notificationSoundEnabled = true,
    this.notificationVibrationEnabled = true,
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
    bool? isLoggingEnabled,
    bool? pushNotificationsEnabled,
    bool? notificationSoundEnabled,
    bool? notificationVibrationEnabled,
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
      isLoggingEnabled: isLoggingEnabled ?? this.isLoggingEnabled,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      notificationSoundEnabled: notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationVibrationEnabled: notificationVibrationEnabled ?? this.notificationVibrationEnabled,
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
        'pushNotificationsEnabled': pushNotificationsEnabled,
        'notificationSoundEnabled': notificationSoundEnabled,
        'notificationVibrationEnabled': notificationVibrationEnabled,
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
      isLoggingEnabled: false,
      pushNotificationsEnabled: json['pushNotificationsEnabled'] as bool? ?? true,
      notificationSoundEnabled: json['notificationSoundEnabled'] as bool? ?? true,
      notificationVibrationEnabled: json['notificationVibrationEnabled'] as bool? ?? true,
    );
  }
}
