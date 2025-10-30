import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

class RestoreMessageHandler {
  final Logger _logger = Logger();

  Future<Map<String, dynamic>?> unwrapAndDecode(
    NostrEvent event,
    NostrKeyPairs tradeKey,
  ) async {
    try {
      final unwrapped = await event.mostroUnWrap(tradeKey);

      if (unwrapped.content == null || unwrapped.content!.isEmpty) {
        return null;
      }

      final content = jsonDecode(unwrapped.content!);

      if (content is! List || content.isEmpty) {
        return null;
      }

      return content[0] as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.e('Failed to unwrap message', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<NostrEvent> createWrappedRequest({
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs masterKey,
    required String mostroPubkey,
    required Map<String, dynamic> message,
  }) async {
    final rumor = NostrEvent.fromPartialData(
      keyPairs: tradeKey,
      content: jsonEncode([message, null]),
      kind: 1,
      tags: [],
    );

    return await rumor.mostroWrapWithSeparateKeys(
      rumorKeys: tradeKey,
      sealKeys: masterKey,
      receiverPubkey: mostroPubkey,
    );
  }

  Future<NostrEvent> createRestoreRequest({
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs masterKey,
    required String mostroPubkey,
  }) async {
    final message = {
      'restore': {
        'version': 1,
        'action': 'restore-session',
        'payload': null,
      }
    };

    return createWrappedRequest(
      tradeKey: tradeKey,
      masterKey: masterKey,
      mostroPubkey: mostroPubkey,
      message: message,
    );
  }

  Future<NostrEvent> createOrderDetailsRequest({
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs masterKey,
    required String mostroPubkey,
    required List<String> orderIds,
  }) async {
    final message = {
      'order': {
        'version': 1,
        'action': 'orders',
        'payload': {'ids': orderIds}
      }
    };

    return createWrappedRequest(
      tradeKey: tradeKey,
      masterKey: masterKey,
      mostroPubkey: mostroPubkey,
      message: message,
    );
  }

  Future<NostrEvent> createLastTradeIndexRequest({
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs masterKey,
    required String mostroPubkey,
  }) async {
    final message = {
      'restore': {
        'version': 1,
        'action': 'last-trade-index',
        'payload': null
      }
    };

    return createWrappedRequest(
      tradeKey: tradeKey,
      masterKey: masterKey,
      mostroPubkey: mostroPubkey,
      message: message,
    );
  }
}
