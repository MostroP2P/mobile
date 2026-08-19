import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/last_trade_index_response.dart';
import 'package:mostro_mobile/data/models/next_trade.dart';
import 'package:mostro_mobile/data/models/nostr_filter.dart';
import 'package:mostro_mobile/data/models/orders_request.dart';
import 'package:mostro_mobile/data/models/orders_response.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/payment_failed.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/data/models/rating_user.dart';
import 'package:mostro_mobile/data/models/text_message.dart';

/// 64-char hex string standing in for a secp256k1 pubkey.
const _pubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> orderDetailJson({
  int? minAmount,
  int? maxAmount,
  int? createdAt,
  int? expiresAt,
  String? buyerTradePubkey,
  String? sellerTradePubkey,
}) =>
    <String, dynamic>{
      'id': 'order-1',
      'kind': 'sell',
      'status': 'pending',
      'amount': 50000,
      'fiat_code': 'USD',
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'fiat_amount': 100,
      'payment_method': 'Wire transfer',
      'premium': 3,
      'buyer_trade_pubkey': buyerTradePubkey,
      'seller_trade_pubkey': sellerTradePubkey,
      'created_at': createdAt,
      'expires_at': expiresAt,
    };

void main() {
  group('NostrFilterX.fromJsonSafe', () {
    test('maps the standard nostr filter fields', () {
      final filter = NostrFilterX.fromJsonSafe(const {
        'ids': ['id1'],
        'authors': ['author1'],
        'kinds': [1, 38383],
        '#e': ['e1'],
        '#p': ['p1'],
        '#t': ['t1'],
        '#a': ['a1'],
        'limit': 25,
        'search': 'query',
      });

      expect(filter.ids, ['id1']);
      expect(filter.authors, ['author1']);
      expect(filter.kinds, [1, 38383]);
      expect(filter.e, ['e1']);
      expect(filter.p, ['p1']);
      expect(filter.t, ['t1']);
      expect(filter.a, ['a1']);
      expect(filter.limit, 25);
      expect(filter.search, 'query');
      expect(filter.additionalFilters, isNull);
    });

    test('converts since and until from epoch seconds', () {
      final filter = NostrFilterX.fromJsonSafe(const {
        'since': 1700000000,
        'until': 1700003600,
      });

      expect(
          filter.since, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      expect(
          filter.until, DateTime.fromMillisecondsSinceEpoch(1700003600 * 1000));
    });

    test('leaves every field null for an empty filter', () {
      final filter = NostrFilterX.fromJsonSafe(const {});

      expect(filter.ids, isNull);
      expect(filter.since, isNull);
      expect(filter.until, isNull);
      expect(filter.limit, isNull);
      expect(filter.search, isNull);
      expect(filter.additionalFilters, isNull);
    });

    test('collects unknown keys into additionalFilters', () {
      final filter = NostrFilterX.fromJsonSafe(const {
        'kinds': [1],
        '#d': ['custom'],
        'mostro': 'yes',
      });

      expect(filter.additionalFilters, {
        '#d': ['custom'],
        'mostro': 'yes',
      });
    });

    test('drops values of the wrong type instead of throwing', () {
      final filter = NostrFilterX.fromJsonSafe(const {
        'ids': 'not-a-list',
        'limit': 'not-an-int',
        'since': 'not-an-int',
        'search': 42,
      });

      expect(filter.ids, isNull);
      expect(filter.limit, isNull);
      expect(filter.since, isNull);
      expect(filter.search, isNull);
    });

    test('safeCast and castList guard against wrong types', () {
      expect(NostrFilterX.safeCast<int>(5), 5);
      expect(NostrFilterX.safeCast<int>('5'), isNull);
      expect(NostrFilterX.castList<String>(const ['a']), ['a']);
      expect(NostrFilterX.castList<String>('a'), isNull);
    });
  });

  group('NostrRequestX.fromJson', () {
    test('builds a request from a list of filters', () {
      final request = NostrRequestX.fromJson([
        {
          'kinds': [38383]
        },
        {
          'authors': ['author']
        },
      ]);

      expect(request.filters, hasLength(2));
      expect(request.filters.first.kinds, [38383]);
      expect(request.filters.last.authors, ['author']);
    });

    test('builds an empty request from an empty list', () {
      expect(NostrRequestX.fromJson(const []).filters, isEmpty);
    });
  });

  group('OrdersPayload', () {
    test('round-trips its list of ids', () {
      const payload = OrdersPayload(ids: ['a', 'b']);

      expect(payload.type, 'orders');
      expect(payload.toJson(), {
        'ids': ['a', 'b']
      });
      expect(OrdersPayload.fromJson(payload.toJson()).ids, ['a', 'b']);
    });

    test('parses an empty id list', () {
      expect(OrdersPayload.fromJson(const {'ids': []}).ids, isEmpty);
    });
  });

  group('OrdersResponse', () {
    test('parses a list of order details', () {
      final response = OrdersResponse.fromJson({
        'orders': [orderDetailJson(createdAt: 1700000000)],
      });

      expect(response.type, 'orders');
      expect(response.orders, hasLength(1));
      expect(response.orders.single.id, 'order-1');
      expect(response.orders.single.createdAt, 1700000000);
    });

    test('falls back to an empty list when orders is missing or null', () {
      expect(OrdersResponse.fromJson(const {}).orders, isEmpty);
      expect(OrdersResponse.fromJson(const {'orders': null}).orders, isEmpty);
    });

    test('survives a JSON round trip', () {
      final original = OrdersResponse.fromJson({
        'orders': [
          orderDetailJson(
            minAmount: 10,
            maxAmount: 100,
            createdAt: 1700000000,
            expiresAt: 1700003600,
            buyerTradePubkey: _pubkey,
            sellerTradePubkey: _pubkey,
          )
        ],
      });

      final restored = OrdersResponse.fromJson(original.toJson());
      final detail = restored.orders.single;

      expect(detail.kind, 'sell');
      expect(detail.status, 'pending');
      expect(detail.amount, 50000);
      expect(detail.fiatCode, 'USD');
      expect(detail.fiatAmount, 100);
      expect(detail.paymentMethod, 'Wire transfer');
      expect(detail.premium, 3);
      expect(detail.minAmount, 10);
      expect(detail.maxAmount, 100);
      expect(detail.buyerTradePubkey, _pubkey);
      expect(detail.sellerTradePubkey, _pubkey);
      expect(detail.expiresAt, 1700003600);
    });

    test('leaves the optional detail fields null when absent', () {
      final detail = OrderDetail.fromJson(orderDetailJson());

      expect(detail.minAmount, isNull);
      expect(detail.maxAmount, isNull);
      expect(detail.buyerTradePubkey, isNull);
      expect(detail.sellerTradePubkey, isNull);
      expect(detail.createdAt, isNull);
      expect(detail.expiresAt, isNull);
    });
  });

  group('NextTrade', () {
    test('serialises as a [key, index] pair', () {
      final next = NextTrade(key: _pubkey, index: 7);

      expect(next.type, 'next_trade');
      expect(next.toJson(), {
        'next_trade': [_pubkey, 7]
      });
    });

    test('parses a two-element list', () {
      final next = NextTrade.fromJson([_pubkey, 7]);

      expect(next.key, _pubkey);
      expect(next.index, 7);
    });

    test('throws FormatException for anything else', () {
      expect(() => NextTrade.fromJson(const [_pubkey]), throwsFormatException);
      expect(() => NextTrade.fromJson(const [_pubkey, 1, 2]),
          throwsFormatException);
      expect(() => NextTrade.fromJson(const {'key': _pubkey}),
          throwsFormatException);
      expect(() => NextTrade.fromJson(null), throwsFormatException);
    });
  });

  group('Peer', () {
    test('serialises the pubkey under a nested peer object', () {
      final peer = Peer(publicKey: _pubkey);

      expect(peer.type, 'peer');
      expect(peer.toJson(), {
        'peer': {'pubkey': _pubkey}
      });
    });

    test('parses a pubkey object', () {
      expect(Peer.fromJson(const {'pubkey': _pubkey}).publicKey, _pubkey);
    });

    test('parses the daemon taker-reputation notice (empty pubkey)', () {
      // Exact wire shape from mostrod's notify_taker_reputation()
      final peer = Peer.fromJson(const {
        'pubkey': '',
        'reputation': {
          'rating': 4.375,
          'reviews': 4,
          'operating_days': 64,
        },
      });

      expect(peer.publicKey, isEmpty);
      expect(peer.reputation, isNotNull);
      expect(peer.reputation!.rating, 4.375);
      expect(peer.reputation!.reviews, 4);
      expect(peer.reputation!.operatingDays, 64);
    });

    test('parses a zeroed reputation (new user or full privacy)', () {
      final peer = Peer.fromJson(const {
        'pubkey': '',
        'reputation': {'rating': 0.0, 'reviews': 0, 'operating_days': 0},
      });

      expect(peer.reputation!.rating, 0.0);
      expect(peer.reputation!.reviews, 0);
      expect(peer.reputation!.operatingDays, 0);
    });

    test('parses a real pubkey with reputation absent (fiat-sent-ok shape)',
        () {
      final peer = Peer.fromJson(const {'pubkey': _pubkey});

      expect(peer.publicKey, _pubkey);
      expect(peer.reputation, isNull);
    });

    test('round-trips the reputation through toJson', () {
      final peer = Peer.fromJson(const {
        'pubkey': '',
        'reputation': {'rating': 4.375, 'reviews': 4, 'operating_days': 64},
      });

      expect(peer.toJson(), {
        'peer': {
          'pubkey': '',
          'reputation': {'rating': 4.375, 'reviews': 4, 'operating_days': 64},
        }
      });
      expect(Peer.fromJson(peer.toJson()['peer']), equals(peer));
    });

    test('rejects a non-empty pubkey that is not 64 hex characters', () {
      expect(() => Peer(publicKey: 'abc'), throwsArgumentError);
      expect(() => Peer(publicKey: 'z' * 64), throwsArgumentError);
    });

    test('throws FormatException for malformed JSON', () {
      expect(() => Peer.fromJson(const {}), throwsFormatException);
      expect(() => Peer.fromJson(const {'pubkey': 42}), throwsFormatException);
      expect(() => Peer.fromJson(const {'pubkey': 'short'}),
          throwsFormatException);
    });

    test('compares by pubkey and reputation', () {
      expect(Peer(publicKey: _pubkey), Peer(publicKey: _pubkey));
      expect(
        Peer(publicKey: _pubkey).hashCode,
        Peer(publicKey: _pubkey).hashCode,
      );
      expect(
        Peer(publicKey: _pubkey),
        isNot(equals(Peer(
          publicKey: _pubkey,
          reputation: const UserInfo(rating: 5.0, reviews: 1, operatingDays: 1),
        ))),
      );
    });
  });

  group('PaymentFailed', () {
    test('round-trips attempts and retry interval', () {
      final failed = PaymentFailed.fromJson(const {
        'payment_attempts': 3,
        'payment_retries_interval': 60,
      });

      expect(failed.type, 'payment_failed');
      expect(failed.paymentAttempts, 3);
      expect(failed.paymentRetriesInterval, 60);
      expect(failed.toJson(), {
        'payment_failed': {
          'payment_attempts': 3,
          'payment_retries_interval': 60,
        }
      });
    });
  });

  group('LastTradeIndexResponse', () {
    test('parses the trade index and defaults noHistoryFound to false', () {
      final response =
          LastTradeIndexResponse.fromJson(const {'trade_index': 12});

      expect(response.type, 'last-trade-index');
      expect(response.tradeIndex, 12);
      expect(response.noHistoryFound, isFalse);
      expect(response.toJson(), {'trade_index': 12});
    });

    test('can be constructed to signal that no history was found', () {
      const response =
          LastTradeIndexResponse(tradeIndex: 0, noHistoryFound: true);

      expect(response.noHistoryFound, isTrue);
    });
  });

  group('Payload.fromJson dispatch', () {
    test('routes a peer payload', () {
      final payload = Payload.fromJson(const {
        'peer': {'pubkey': _pubkey}
      });

      expect(payload, isA<Peer>());
      expect((payload as Peer).publicKey, _pubkey);
    });

    test('routes a rating_user payload', () {
      final payload = Payload.fromJson(const {'rating_user': 5});

      expect(payload, isA<RatingUser>());
      expect((payload as RatingUser).userRating, 5);
    });

    test('routes a payment_failed payload', () {
      final payload = Payload.fromJson(const {
        'payment_failed': {
          'payment_attempts': 1,
          'payment_retries_interval': 10,
        }
      });

      expect(payload, isA<PaymentFailed>());
    });

    test('routes a next_trade payload', () {
      final payload = Payload.fromJson(const {
        'next_trade': [_pubkey, 2]
      });

      expect(payload, isA<NextTrade>());
      expect((payload as NextTrade).index, 2);
    });

    test('routes a text_message payload', () {
      final payload = Payload.fromJson(const {'text_message': 'hello'});

      expect(payload, isA<TextMessage>());
      expect((payload as TextMessage).message, 'hello');
    });

    test('throws UnsupportedError for an unknown payload', () {
      expect(
          () => Payload.fromJson(const {'mystery': 1}), throwsUnsupportedError);
      expect(() => Payload.fromJson(const {}), throwsUnsupportedError);
    });
  });

  group('EmptyPayload', () {
    test('carries no data', () {
      const payload = EmptyPayload();

      expect(payload.type, 'empty');
      expect(payload.toJson(), isEmpty);
    });
  });

  group('storage key enums', () {
    test('SharedPreferencesKeys round-trips every value', () {
      for (final key in SharedPreferencesKeys.values) {
        expect(SharedPreferencesKeys.fromString(key.value), key);
        expect(key.toString(), key.value);
      }
    });

    test('SharedPreferencesKeys exposes the persisted names', () {
      expect(SharedPreferencesKeys.appSettings.value, 'mostro_settings');
      expect(
          SharedPreferencesKeys.mostroCustomNodes.value, 'mostro_custom_nodes');
    });

    test('SharedPreferencesKeys rejects an unknown key', () {
      expect(
          () => SharedPreferencesKeys.fromString('nope'), throwsArgumentError);
    });

    test('SecureStorageKeys round-trips every value', () {
      for (final key in SecureStorageKeys.values) {
        expect(SecureStorageKeys.fromString(key.value), key);
        expect(key.toString(), key.value);
      }
    });

    test('SecureStorageKeys rejects an unknown key', () {
      expect(() => SecureStorageKeys.fromString('nope'), throwsArgumentError);
    });
  });

  group('MostroMessage.isTakerReputationNotice', () {
    MostroMessage<Peer> peerMessage(Action action, Peer peer) =>
        MostroMessage<Peer>(action: action, id: 'order-1', payload: peer);

    test('recognises the empty-pubkey notice on either flow action', () {
      final peer = Peer(
        publicKey: '',
        reputation:
            const UserInfo(rating: 4.375, reviews: 4, operatingDays: 64),
      );

      expect(peerMessage(Action.payInvoice, peer).isTakerReputationNotice,
          isTrue);
      expect(peerMessage(Action.addInvoice, peer).isTakerReputationNotice,
          isTrue);
    });

    test('a Peer carrying a real pubkey is a normal flow message', () {
      expect(
        peerMessage(Action.fiatSentOk, Peer(publicKey: _pubkey))
            .isTakerReputationNotice,
        isFalse,
      );
      expect(
        peerMessage(Action.addInvoice, Peer(publicKey: _pubkey))
            .isTakerReputationNotice,
        isFalse,
      );
    });

    // Empty pubkey is mostrod's only marker for this notice: notify_taker_
    // reputation is the sole emitter, so unknown shapes stay informational
    test('an empty pubkey is the notice even without a reputation', () {
      expect(
        peerMessage(Action.addInvoice, Peer(publicKey: ''))
            .isTakerReputationNotice,
        isTrue,
      );
    });

    // Requiring the action instead would send a future third call site into
    // the status machine, which is what keying on the pubkey prevents
    test('an empty pubkey is the notice on any other action', () {
      expect(
        peerMessage(
          Action.fiatSentOk,
          Peer(
            publicKey: '',
            reputation:
                const UserInfo(rating: 5.0, reviews: 9, operatingDays: 30),
          ),
        ).isTakerReputationNotice,
        isTrue,
      );
    });

    test('a message without a Peer payload is never the notice', () {
      expect(
        MostroMessage(action: Action.payInvoice, id: 'order-1')
            .isTakerReputationNotice,
        isFalse,
      );
    });
  });
}
