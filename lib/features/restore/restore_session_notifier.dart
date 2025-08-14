import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/restore_session_payload.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class RestoreSessionNotifier {
  final WidgetRef ref;
  final _logger = Logger();

  StreamSubscription<MostroMessage?>? _subscription;
  Timer? _timer;

  RestoreSessionNotifier(this.ref);

  Future<int> restore() async {
    final completer = Completer<int>();

    // Subscribe directly to the storage stream
    _subscription = ref
        .read(mostroStorageProvider)
        .watchLatestRestorePayload()
        .listen((MostroMessage? msg) async {
      try {
        if (msg == null) return;
        _logger.i('Restore-session response received from daemon: id=${msg.id}, action=${msg.action}, requestId=${msg.requestId}');
        final payload = msg.getPayload<RestoreSessionPayload>();
        if (payload == null) return;
        _logger.i('Restore-session payload details: orders=${payload.orders.length}, disputes=${payload.disputes.length}');
        final newIndex = await _processPayload(payload);
        await _disposeInternal();
        if (!completer.isCompleted) completer.complete(newIndex);
      } catch (e, st) {
        _logger.e('Error processing restore payload', error: e, stackTrace: st);
        await _disposeInternal();
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    }, onError: (e, st) {
      _logger.e('Error listening restore payload', error: e, stackTrace: st);
      if (!completer.isCompleted) completer.completeError(e, st);
    });

    // Start timeout
    _timer = Timer(Config.restoreSessionTimeout, () {
      _logger.w('Restore-session timed out after ${Config.restoreSessionTimeout.inSeconds}s');
      _disposeInternal();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Restore timed out', Config.restoreSessionTimeout));
      }
    });

    // Send request
    _logger.i('Sending restore-session request to daemon...');
    await ref.read(mostroServiceProvider).sendRestoreRequest();

    return completer.future;
  }

  Future<int> _processPayload(RestoreSessionPayload payload) async {
    final keyManager = ref.read(keyManagerProvider);
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final settings = ref.read(settingsProvider);

    var maxIndex = 0;

    for (final o in payload.orders) {
      if (o.tradeIndex > maxIndex) maxIndex = o.tradeIndex;

      final tradeKey = await keyManager.deriveTradeKeyFromIndex(o.tradeIndex);
      final session = Session(
        startTime: DateTime.now(),
        masterKey: keyManager.masterKeyPair!,
        keyIndex: o.tradeIndex,
        tradeKey: tradeKey,
        fullPrivacy: settings.fullPrivacyMode,
        orderId: o.id,
      );
      await sessionNotifier.saveSession(session);
    }

    // Consider disputes indexes too
    for (final d in payload.disputes) {
      if (d.tradeIndex > maxIndex) maxIndex = d.tradeIndex;
    }

    // Update current key index to resume after highest used index
    await keyManager.setCurrentKeyIndex(maxIndex + 1);

    _logger.i('Restore-session completed. Max index used: $maxIndex');

    return maxIndex + 1;
  }

  Future<void> _disposeInternal() async {
    await _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async => _disposeInternal();
}
