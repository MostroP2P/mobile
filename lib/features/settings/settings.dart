import 'package:mostro_mobile/core/config.dart';

class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroInstance;

  Settings(
      {required this.relays,
      required this.fullPrivacyMode,
      required this.mostroInstance});

  Settings copyWith({List<String>? relays, bool? privacyModeSetting, String? mostroInstance}) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: privacyModeSetting ?? fullPrivacyMode,
      mostroInstance: mostroInstance ?? this.mostroInstance,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroInstance': mostroInstance,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroInstance: json['mostroInstance'] ?? Config.mostroPubKey,
    );
  }
}
