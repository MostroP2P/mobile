import 'package:mostro_mobile/features/settings/settings.dart';

abstract class BackgroundService {
  Future<void> init();
  Future<bool> subscribe(Map<String, dynamic> filter);
  Future<bool> unsubscribe(String subscriptionId);
  void updateSettings(Settings settings);
  Future<void> unsubscribeAll();
  Future<int> getActiveSubscriptionCount();
  Future<void> setForegroundStatus(bool isForeground);
  bool get isRunning;
}
