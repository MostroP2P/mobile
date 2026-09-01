import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/shared/mixins/media_cache_mixin.dart';

/// Every chat notifier held its decrypted media bytes until process exit. The
/// cache is now byte-bounded, and the budget is global: a per-notifier
/// ceiling would have been multiplied by the number of conversations.
void main() {
  EncryptedImageUploadResult meta(int size) => EncryptedImageUploadResult(
        blossomUrl: 'https://blossom/x',
        nonce: '00',
        mimeType: 'image/png',
        originalSize: size,
        width: 1,
        height: 1,
        filename: 'x.png',
        encryptedSize: size,
      );

  Uint8List chunk() => Uint8List(MediaCacheMixin.mediaCacheMaxBytes ~/ 3);

  setUp(MediaCacheMixin.debugResetMediaCache);

  test('evicts the least recently used entries once the cap is exceeded', () {
    final cache = _CacheHost();
    final data = chunk();

    cache.cacheDecryptedImage('a', data, meta(data.length));
    cache.cacheDecryptedImage('b', data, meta(data.length));
    cache.cacheDecryptedImage('c', data, meta(data.length));
    cache.cacheDecryptedImage('d', data, meta(data.length));

    expect(MediaCacheMixin.debugMediaCacheBytes,
        lessThanOrEqualTo(MediaCacheMixin.mediaCacheMaxBytes));
    expect(cache.getCachedImage('a'), isNull,
        reason: 'least recently used entry must be evicted first');
    expect(cache.getCachedImage('d'), isNotNull);
  });

  test('a read promotes an entry, so a hot item is not evicted', () {
    final cache = _CacheHost();
    final data = chunk();

    cache.cacheDecryptedImage('a', data, meta(data.length));
    cache.cacheDecryptedImage('b', data, meta(data.length));
    cache.getCachedImage('a');
    cache.cacheDecryptedImage('c', data, meta(data.length));
    cache.cacheDecryptedImage('d', data, meta(data.length));

    expect(cache.getCachedImage('a'), isNotNull,
        reason: 'read recently: FIFO would have evicted it');
    expect(cache.getCachedImage('b'), isNull);
  });

  test('a read does not change the byte accounting', () {
    final cache = _CacheHost();
    final data = chunk();

    cache.cacheDecryptedImage('a', data, meta(data.length));
    final before = MediaCacheMixin.debugMediaCacheBytes;
    cache.getCachedImage('a');
    cache.getCachedImage('missing');

    expect(MediaCacheMixin.debugMediaCacheBytes, before);
  });

  test('the budget is shared across conversations, not per notifier', () {
    final first = _CacheHost();
    final second = _CacheHost();
    final data = chunk();

    first.cacheDecryptedImage('a', data, meta(data.length));
    first.cacheDecryptedImage('b', data, meta(data.length));
    second.cacheDecryptedImage('c', data, meta(data.length));
    second.cacheDecryptedImage('d', data, meta(data.length));

    expect(MediaCacheMixin.debugMediaCacheBytes,
        lessThanOrEqualTo(MediaCacheMixin.mediaCacheMaxBytes));
    expect(first.getCachedImage('a'), isNull,
        reason: 'a second conversation must not double the ceiling');
  });

  test('clearing one conversation releases only its own bytes', () {
    final first = _CacheHost();
    final second = _CacheHost();
    final data = chunk();

    first.cacheDecryptedImage('a', data, meta(data.length));
    second.cacheDecryptedImage('b', data, meta(data.length));
    first.clearMediaCaches();

    expect(MediaCacheMixin.debugMediaCacheBytes, data.length);
    expect(second.getCachedImage('b'), isNotNull);
  });
}

class _CacheHost with MediaCacheMixin {}
