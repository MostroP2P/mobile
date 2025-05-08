import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';

class TrayManager {
  static final TrayManager _instance = TrayManager._internal();
  factory TrayManager() => _instance;

  final SystemTray _tray = SystemTray();

  TrayManager._internal();

  Future<void> init(
    GlobalKey<NavigatorState> navigatorKey, {
    String iconPath = 'assets/images/launcher-icon.png',
  }) async {
    try {
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
          onClicked: (menuItem) async {
            await dispose();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (Platform.isAndroid || Platform.isIOS) {
                SystemNavigator.pop();
              } else {
                exit(0); // Only as a last resort on desktop
              }
            });
          },
        ),
      ]);

      await _tray.setContextMenu(menu);

      // Handle tray icon click (e.g., double click = open)
      _tray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          navigatorKey.currentState?.pushNamed('/');
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _tray.destroy();
    } catch (e) {
      debugPrint('Failed to destroy system tray: $e');
    }
  }
}
