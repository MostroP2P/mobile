import 'package:mostro_mobile/features/settings/settings.dart';

abstract class BackgroundService {
  Future<void> initialize(Settings settings);
  Future<bool> subscribe(Map<String, dynamic> filter);
  Future<bool> unsubscribe(String subscriptionId);
  Future<void> unsubscribeAll();
  Future<int> getActiveSubscriptionCount();
  void setForegroundStatus(bool isForeground);
}