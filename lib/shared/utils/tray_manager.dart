import 'dart:io';

import 'package:system_tray/system_tray.dart';
import 'package:flutter/material.dart';

class TrayManager {
  static final TrayManager _instance = TrayManager._internal();
  factory TrayManager() => _instance;

  final SystemTray _tray = SystemTray();

  TrayManager._internal();

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    const iconPath = 'assets/images/launcher-icon.png';

    await _tray.initSystemTray(
      iconPath: iconPath,
      toolTip: "Mostro is running",
      title: '',
    );

    final menu = Menu();

    menu.buildFrom([
      MenuItemLabel(
        label: 'Open Mostro',
        onClicked: (menuItem) {
          navigatorKey.currentState?.pushNamed('/');
        },
      ),
      MenuItemLabel(
          label: 'Quit',
          onClicked: (menuItem) {
            _tray.destroy();
            Future.delayed(const Duration(milliseconds: 300), () {
              exit(0);
            });
          }),
    ]);

    await _tray.setContextMenu(menu);

    // Handle tray icon click (e.g., double click = open)
    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        navigatorKey.currentState?.pushNamed('/');
      }
    });
  }
}
