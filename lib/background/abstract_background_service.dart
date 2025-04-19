import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

abstract class BackgroundService {
  Future<void> initialize(Settings settings);
  Future<bool> subscribe(Map<String, dynamic> filter);
  Future<bool> unsubscribe(String subscriptionId);
  void updateSettings(Settings settings);
  Future<void> unsubscribeAll();
  Future<int> getActiveSubscriptionCount();
  void setForegroundStatus(bool isForeground);
  Stream<NostrEvent> get eventsStream;
  bool get isRunning;
}
