class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroPublicKey;
  final String? defaultFiatCode;
  final String? selectedLanguage; // null means use system locale

  static const _unset = Object();

  Settings({
    required this.relays,
    required this.fullPrivacyMode,
    required this.mostroPublicKey,
    this.defaultFiatCode,
    this.selectedLanguage,
  });

  Settings copyWith({
    List<String>? relays,
    bool? fullPrivacyMode,
    String? mostroPublicKey,
    String? defaultFiatCode,
    Object? selectedLanguage = _unset,
  }) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: fullPrivacyMode ?? this.fullPrivacyMode,
      mostroPublicKey: mostroPublicKey ?? this.mostroPublicKey,
      defaultFiatCode: defaultFiatCode ?? this.defaultFiatCode,
      selectedLanguage: identical(selectedLanguage, _unset)
          ? this.selectedLanguage
          : selectedLanguage as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroPublicKey': mostroPublicKey,
        'defaultFiatCode': defaultFiatCode,
        'selectedLanguage': selectedLanguage,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroPublicKey: json['mostroPublicKey'],
      defaultFiatCode: json['defaultFiatCode'],
      selectedLanguage: json['selectedLanguage'],
    );
  }
}
