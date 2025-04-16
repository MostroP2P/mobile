import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/background/background.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'abstract_background_service.dart';

class MobileBackgroundService implements BackgroundService {
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  final service = FlutterBackgroundService();

  @override
  Future<void> initialize(Settings settings) async {
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: serviceMain,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: serviceMain,
        isForegroundMode: false,
        autoStartOnBoot: true,
      ),
    );

    service.invoke(
      'settings-change',
      settings.toJson(),
    );

    service.on('nostr-event').listen((data) {
      _eventsController.add(data!);
    });
  }

  @override
  void subscribe(Map<String, dynamic> filter) {
    service.invoke(
      'create-subscription',
      {'filter': filter},
    );
  }
  
  @override
  void setForegroundStatus(bool isForeground) {
    service.invoke('app-foreground-status', {
      'isForeground': isForeground,
    });
  }
}
