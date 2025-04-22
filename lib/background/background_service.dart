import 'dart:io';
import 'package:mostro_mobile/background/abstract_background_service.dart';
import 'package:mostro_mobile/background/desktop_background_service.dart';
import 'package:mostro_mobile/background/mobile_background_service.dart';
import 'package:mostro_mobile/features/settings/settings.dart';


BackgroundService createBackgroundService(Settings settings) {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileBackgroundService(settings);
  } else {
    return DesktopBackgroundService();
  }
}
