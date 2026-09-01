import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/shared/mixins/media_cache_mixin.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';

/// Startup eagerly created an OrderNotifier (storage watcher + listeners) and
/// a ChatRoomNotifier (history decrypt) for EVERY session of the last 30
/// days, terminal or not, and each chat notifier held its decrypted media
/// bytes until process exit. Terminal orders now initialize lazily and the
/// media cache is byte-bounded.
void main() {
  MostroMessage withStatus(Status status) => MostroMessage(
        action: Action.newOrder,
        id: 'o1',
        payload: Order(
          kind: OrderType.sell,
          status: status,
          fiatCode: 'VES',
          fiatAmount: 100,
          paymentMethod: 'cash',
        ),
      );

  group('isTerminalOrderMessage', () {
    test('terminal statuses skip eager initialization', () {
      expect(isTerminalOrderMessage(withStatus(Status.canceled)), isTrue);
      expect(isTerminalOrderMessage(withStatus(Status.success)), isTrue);
      expect(
          isTerminalOrderMessage(withStatus(Status.canceledByAdmin)), isTrue);
    });

    test('live statuses keep eager initialization', () {
      expect(isTerminalOrderMessage(withStatus(Status.pending)), isFalse);
      expect(isTerminalOrderMessage(withStatus(Status.active)), isFalse);
      expect(isTerminalOrderMessage(withStatus(Status.fiatSent)), isFalse);
    });

    test('no message or no order payload counts as live (conservative)', () {
      expect(isTerminalOrderMessage(null), isFalse);
      expect(
        isTerminalOrderMessage(MostroMessage(action: Action.rate, id: 'o1')),
        isFalse,
      );
    });
  });

  group('MediaCacheMixin byte bound', () {
    test('evicts the oldest entries once the cap is exceeded', () {
      final cache = _CacheHost();
      final chunk = Uint8List(MediaCacheMixin.mediaCacheMaxBytes ~/ 3);
      final meta = EncryptedImageUploadResult(
        blossomUrl: 'https://blossom/x',
        nonce: '00',
        mimeType: 'image/png',
        originalSize: chunk.length,
        width: 1,
        height: 1,
        filename: 'x.png',
        encryptedSize: chunk.length,
      );

      cache.cacheDecryptedImage('a', chunk, meta);
      cache.cacheDecryptedImage('b', chunk, meta);
      cache.cacheDecryptedImage('c', chunk, meta);
      cache.cacheDecryptedImage('d', chunk, meta);

      expect(cache.debugMediaCacheBytes,
          lessThanOrEqualTo(MediaCacheMixin.mediaCacheMaxBytes));
      expect(cache.getCachedImage('a'), isNull,
          reason: 'oldest entry must be evicted first');
      expect(cache.getCachedImage('d'), isNotNull);
    });
  });
}

class _CacheHost with MediaCacheMixin {}
