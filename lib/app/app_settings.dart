class AppSettings {
  final bool isFirstLaunch;

  AppSettings(this.isFirstLaunch);

  factory AppSettings.intial() => AppSettings(true);

  AppSettings copyWith({bool isFirstLaunch = false}) {
    return AppSettings(isFirstLaunch);
  }
}
