import 'package:mostro_mobile/features/settings/settings.dart';

abstract class BackgroundService {
  Future<void> initialize(Settings settings);
  void subscribe(Map<String, dynamic> filter);
  void setForegroundStatus(bool isForeground);
}
