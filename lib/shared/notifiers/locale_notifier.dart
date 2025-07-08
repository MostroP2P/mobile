import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that tracks system locale changes
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(ui.PlatformDispatcher.instance.locale) {
    // Listen to system locale changes
    ui.PlatformDispatcher.instance.onLocaleChanged = _onLocaleChanged;
  }

  void _onLocaleChanged() {
    final newLocale = ui.PlatformDispatcher.instance.locale;
    if (state != newLocale) {
      state = newLocale;
    }
  }

  @override
  void dispose() {
    // Clean up the listener
    ui.PlatformDispatcher.instance.onLocaleChanged = null;
    super.dispose();
  }
}

/// Provider for system locale changes
final systemLocaleProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
