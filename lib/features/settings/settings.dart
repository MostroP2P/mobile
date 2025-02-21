import 'package:mostro_mobile/core/config.dart';

class Settings {
  final bool fullPrivacyMode;
  final List<String> relays;
  final String mostroInstance;
  final String? defaultFiatCode;

  Settings(
      {required this.relays,
      required this.fullPrivacyMode,
      required this.mostroInstance,
      this.defaultFiatCode});

  Settings copyWith(
      {List<String>? relays,
      bool? privacyModeSetting,
      String? mostroInstance,
      String? defaultFiatCode}) {
    return Settings(
      relays: relays ?? this.relays,
      fullPrivacyMode: privacyModeSetting ?? fullPrivacyMode,
      mostroInstance: mostroInstance ?? this.mostroInstance,
      defaultFiatCode: defaultFiatCode ?? this.defaultFiatCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'relays': relays,
        'fullPrivacyMode': fullPrivacyMode,
        'mostroInstance': mostroInstance,
        'defaultFiatCode': defaultFiatCode,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      relays: (json['relays'] as List<dynamic>?)?.cast<String>() ?? [],
      fullPrivacyMode: json['fullPrivacyMode'] as bool,
      mostroInstance: json['mostroInstance'] ?? Config.mostroPubKey,
      defaultFiatCode: json['defaultFiatCode'],
    );
  }
}
