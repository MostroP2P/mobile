import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final service = FlutterBackgroundService();
    await service.startService();

    return Future.value(true);
  });
}

Future<void> initializeWorkManager() async {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  await Workmanager().registerPeriodicTask(
    "mostroWebSocketTask",
    "mostroWebSocketTask",
    frequency: Duration(hours: 1),
    initialDelay: Duration(minutes: 1),
  );
}