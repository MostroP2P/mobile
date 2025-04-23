import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

abstract class BackgroundService {
  Future<void> init();
  void subscribe(List<NostrFilter> filters);
  void updateSettings(Settings settings);
  Future<void> setForegroundStatus(bool isForeground);
  Future<bool> unsubscribe(String subscriptionId);
  Future<void> unsubscribeAll();
  Future<int> getActiveSubscriptionCount();
  bool get isRunning;
}
