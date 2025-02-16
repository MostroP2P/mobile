class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;

  Settings({required this.relays, required this.fullPrivacyMode});

  Settings copyWith({List<String>? relays, bool? privacyModeSetting}) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: privacyModeSetting ?? fullPrivacyMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json[' fullPrivacyMode'] as bool,
    );
  }
}
