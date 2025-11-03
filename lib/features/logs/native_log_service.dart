import 'dart:async';
import 'package:flutter/services.dart';

class NativeLogService {
  static const EventChannel _logcatStream = EventChannel('native_logcat_stream');

  Stream<String>? _nativeLogStream;
  StreamSubscription? _subscription;
  bool _isListening = false;

  Stream<String> get nativeLogStream {
    if (_nativeLogStream == null && !_isListening) {
      _isListening = true;
      _nativeLogStream = _logcatStream
          .receiveBroadcastStream()
          .map((event) => event.toString())
          .handleError((error) {
        print('❌ Error in native logcat stream: $error');
      }).where((log) => log.isNotEmpty && log.trim().isNotEmpty);
    }

    return _nativeLogStream!;
  }

  bool get isListening => _isListening;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    // Reset stream to allow restart
    _nativeLogStream = null;
    _isListening = false;
  }
}