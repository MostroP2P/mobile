class AppSettings {
  final bool fullPrivacyMode;

  AppSettings({required this.fullPrivacyMode});

  factory AppSettings.intial() => AppSettings(fullPrivacyMode: false);

  AppSettings copyWith({required bool fullPrivacyMode}) {
    return AppSettings(fullPrivacyMode: fullPrivacyMode);
  }
  
}
