import 'dart:async';
import 'package:flutter/services.dart';

class NativeLogService {
  static const EventChannel _logcatStream = EventChannel('native_logcat_stream');

  Stream<String>? _nativeLogStream;
  StreamSubscription? _subscription;
  bool _isListening = false;

  Stream<String> get nativeLogStream {
    if (_nativeLogStream == null) {
      _nativeLogStream = _logcatStream
          .receiveBroadcastStream()
          .map((event) => event.toString())
          .handleError((error) {
        print('❌ Error en stream de logcat nativo: $error');
      }).where((log) => log.isNotEmpty && log.trim().isNotEmpty);

      _isListening = true;
    }

    return _nativeLogStream!;
  }

  bool get isListening => _isListening;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _nativeLogStream = null;
    _isListening = false;
  }
}