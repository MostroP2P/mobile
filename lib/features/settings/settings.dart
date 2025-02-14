class Settings {
  final bool fullPrivacyMode;

  Settings({required this.fullPrivacyMode});

  factory Settings.intial() => Settings(fullPrivacyMode: false);

  Settings copyWith({required bool fullPrivacyMode}) {
    return Settings(fullPrivacyMode: fullPrivacyMode);
  }
}
