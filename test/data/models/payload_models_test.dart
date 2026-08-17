import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/amount.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/range_amount.dart';
import 'package:mostro_mobile/data/models/rating.dart';
import 'package:mostro_mobile/data/models/rating_user.dart';
import 'package:mostro_mobile/data/models/text_message.dart';

/// Minimal synthetic currency payload used across the Currency tests.
Map<String, dynamic> currencyJson({
  Object? decimalDigits = 2,
  Object? price = true,
  String? locale,
}) =>
    <String, dynamic>{
      'symbol': r'$',
      'name': 'US Dollar',
      'symbol_native': r'$',
      'code': 'USD',
      'emoji': '🇺🇸',
      'decimal_digits': decimalDigits,
      'name_plural': 'US dollars',
      'price': price,
      if (locale != null) 'locale': locale,
    };

NostrEvent chatEvent(String id, int createdAtSeconds) => NostrEvent(
      id: id,
      kind: 1059,
      content: 'ciphertext-$id',
      sig: 'sig-$id',
      pubkey: 'f' * 64,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
      tags: const [],
    );

void main() {
  group('Amount', () {
    test('serialises under the amount payload key', () {
      expect(Amount(amount: 21000).toJson(), {'amount': 21000});
      expect(Amount(amount: 0).type, 'amount');
    });

    test('rejects a negative amount', () {
      expect(() => Amount(amount: -1), throwsArgumentError);
    });

    test('parses an int, a numeric string and a wrapped object', () {
      expect(Amount.fromJson(50).amount, 50);
      expect(Amount.fromJson('50').amount, 50);
      expect(Amount.fromJson(const {'amount': 50}).amount, 50);
      expect(Amount.fromJson(const {'amount': '50'}).amount, 50);
    });

    test('throws FormatException for unusable input', () {
      expect(() => Amount.fromJson(null), throwsFormatException);
      expect(() => Amount.fromJson('abc'), throwsFormatException);
      expect(() => Amount.fromJson(1.5), throwsFormatException);
      expect(() => Amount.fromJson(const <String, dynamic>{}),
          throwsFormatException);
      expect(
          () => Amount.fromJson(const {'amount': 1.5}), throwsFormatException);
      expect(() => Amount.fromJson(-5), throwsFormatException);
    });

    test('compares by value', () {
      expect(Amount(amount: 10), Amount(amount: 10));
      expect(Amount(amount: 10).hashCode, Amount(amount: 10).hashCode);
      expect(Amount(amount: 10), isNot(Amount(amount: 11)));
      expect(Amount(amount: 10).toString(), 'Amount(amount: 10)');
    });
  });

  group('RatingUser', () {
    test('serialises under the rating_user payload key', () {
      expect(RatingUser(userRating: 4).toJson(), {'rating_user': 4});
      expect(RatingUser(userRating: 4).type, 'rating_user');
    });

    test('accepts the full 1..5 range', () {
      for (var i = 1; i <= 5; i++) {
        expect(RatingUser(userRating: i).userRating, i);
      }
    });

    test('rejects ratings outside 1..5 at construction time', () {
      expect(() => RatingUser(userRating: 0), throwsArgumentError);
      expect(() => RatingUser(userRating: 6), throwsArgumentError);
    });

    test('parses an int, a numeric string and both object shapes', () {
      expect(RatingUser.fromJson(3).userRating, 3);
      expect(RatingUser.fromJson('3').userRating, 3);
      expect(RatingUser.fromJson(const {'user_rating': 3}).userRating, 3);
      expect(RatingUser.fromJson(const {'rating': 3}).userRating, 3);
      expect(RatingUser.fromJson(const {'rating': '3'}).userRating, 3);
    });

    test('throws FormatException for unusable input', () {
      expect(() => RatingUser.fromJson(null), throwsFormatException);
      expect(() => RatingUser.fromJson('x'), throwsFormatException);
      expect(() => RatingUser.fromJson(9), throwsFormatException);
      expect(() => RatingUser.fromJson(0), throwsFormatException);
      expect(() => RatingUser.fromJson(const <String, dynamic>{}),
          throwsFormatException);
      expect(() => RatingUser.fromJson(const {'rating': 1.5}),
          throwsFormatException);
    });

    test('compares by value', () {
      expect(RatingUser(userRating: 2), RatingUser(userRating: 2));
      expect(RatingUser(userRating: 2).hashCode, 2.hashCode);
      expect(RatingUser(userRating: 2), isNot(RatingUser(userRating: 3)));
      expect(RatingUser(userRating: 2).toString(), 'RatingUser(userRating: 2)');
    });
  });

  group('TextMessage', () {
    test('serialises under the text_message payload key', () {
      expect(TextMessage(message: 'hi').toJson(), {'text_message': 'hi'});
      expect(TextMessage(message: 'hi').type, 'text_message');
    });

    test('rejects an empty message at construction time', () {
      expect(() => TextMessage(message: ''), throwsArgumentError);
    });

    test('accepts both the message and text_message keys', () {
      expect(TextMessage.fromJson(const {'message': 'a'}).message, 'a');
      expect(TextMessage.fromJson(const {'text_message': 'b'}).message, 'b');
    });

    test('prefers message over text_message when both are present', () {
      final parsed =
          TextMessage.fromJson(const {'message': 'a', 'text_message': 'b'});

      expect(parsed.message, 'a');
    });

    test('throws FormatException for a missing or empty message', () {
      expect(() => TextMessage.fromJson(const <String, dynamic>{}),
          throwsFormatException);
      expect(() => TextMessage.fromJson(const {'message': ''}),
          throwsFormatException);
    });

    test('compares by value', () {
      expect(TextMessage(message: 'x'), TextMessage(message: 'x'));
      expect(TextMessage(message: 'x').hashCode, 'x'.hashCode);
      expect(TextMessage(message: 'x'), isNot(TextMessage(message: 'y')));
      expect(TextMessage(message: 'x').toString(), 'TextMessage(message: x)');
    });
  });

  group('CantDo', () {
    test('serialises as a nested cant-do object', () {
      final cantDo = CantDo(cantDoReason: CantDoReason.invalidAmount);

      expect(cantDo.toJson(), {
        'cant_do': {'cant-do': 'invalid_amount'}
      });
      expect(cantDo.type, 'cant_do');
    });

    test('parses a plain string reason', () {
      final cantDo = CantDo.fromJson(const {'cant_do': 'invalid_signature'});

      expect(cantDo.cantDoReason, CantDoReason.invalidSignature);
    });

    test('parses a nested object reason', () {
      final cantDo = CantDo.fromJson(const {
        'cant_do': {'cant-do': 'not_found'}
      });

      expect(cantDo.cantDoReason, CantDoReason.notFound);
    });

    test('survives a round trip through its own JSON', () {
      final original = CantDo(cantDoReason: CantDoReason.pendingOrderExists);

      expect(CantDo.fromJson(original.toJson()), original);
    });

    test('throws FormatException for unusable input', () {
      expect(() => CantDo.fromJson(const <String, dynamic>{}),
          throwsFormatException);
      expect(
          () => CantDo.fromJson(const {'cant_do': ''}), throwsFormatException);
      expect(
          () => CantDo.fromJson(const {'cant_do': 42}), throwsFormatException);
      expect(() => CantDo.fromJson(const {'cant_do': <String, dynamic>{}}),
          throwsFormatException);
      expect(() => CantDo.fromJson(const {'cant_do': 'unknown_reason'}),
          throwsFormatException);
    });

    test('compares by value', () {
      final a = CantDo(cantDoReason: CantDoReason.notFound);
      final b = CantDo(cantDoReason: CantDoReason.notFound);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(CantDo(cantDoReason: CantDoReason.invalidPeer)));
      expect(a.toString(), 'CantDo(cantDoReason: not_found)');
    });
  });

  group('RangeAmount', () {
    test('reports whether it is a range', () {
      expect(RangeAmount(10, 100).isRange(), isTrue);
      expect(RangeAmount(10, null).isRange(), isFalse);
      expect(RangeAmount.empty().isRange(), isFalse);
      expect(RangeAmount.empty().minimum, 0);
    });

    test('renders a single value or a range', () {
      expect(RangeAmount(10, 100).toString(), '10 - 100');
      expect(RangeAmount(10, null).toString(), '10');
    });

    test('rejects negative and inverted bounds', () {
      expect(() => RangeAmount(-1, null), throwsArgumentError);
      expect(() => RangeAmount(0, -1), throwsArgumentError);
      expect(() => RangeAmount(100, 10), throwsArgumentError);
    });

    test('parses a nostr fa tag with a minimum only', () {
      final range = RangeAmount.fromList(const ['fa', '100']);

      expect(range.minimum, 100);
      expect(range.maximum, isNull);
    });

    test('parses a nostr fa tag with both bounds', () {
      final range = RangeAmount.fromList(const ['fa', '100', '500']);

      expect(range.minimum, 100);
      expect(range.maximum, 500);
    });

    test('truncates decimal bounds coming from the fa tag', () {
      final range = RangeAmount.fromList(const ['fa', '100.9', '500.7']);

      expect(range.minimum, 100);
      expect(range.maximum, 500);
    });

    test('treats an empty maximum in the fa tag as no maximum', () {
      final range = RangeAmount.fromList(const ['fa', '100', '']);

      expect(range.maximum, isNull);
    });

    test('throws FormatException for a malformed fa tag', () {
      expect(() => RangeAmount.fromList(const ['fa']), throwsFormatException);
      expect(
          () => RangeAmount.fromList(const ['fa', '']), throwsFormatException);
      expect(() => RangeAmount.fromList(const ['fa', 'abc']),
          throwsFormatException);
      expect(() => RangeAmount.fromList(const ['fa', '10', 'abc']),
          throwsFormatException);
    });

    test('parses int and string bounds from JSON', () {
      expect(RangeAmount.fromJson(const {'minimum': 1, 'maximum': 2}),
          RangeAmount(1, 2));
      expect(RangeAmount.fromJson(const {'minimum': '1', 'maximum': '2'}),
          RangeAmount(1, 2));
      expect(RangeAmount.fromJson(const {'minimum': 1}), RangeAmount(1, null));
    });

    test('throws FormatException for malformed JSON bounds', () {
      expect(() => RangeAmount.fromJson(const <String, dynamic>{}),
          throwsFormatException);
      expect(() => RangeAmount.fromJson(const {'minimum': 1.5}),
          throwsFormatException);
      expect(() => RangeAmount.fromJson(const {'minimum': 'x'}),
          throwsFormatException);
      expect(() => RangeAmount.fromJson(const {'minimum': 1, 'maximum': 'x'}),
          throwsFormatException);
      expect(() => RangeAmount.fromJson(const {'minimum': 1, 'maximum': 1.5}),
          throwsFormatException);
    });

    test('omits a null maximum when serialising', () {
      expect(RangeAmount(5, null).toJson(), {'minimum': 5});
      expect(RangeAmount(5, 9).toJson(), {'minimum': 5, 'maximum': 9});
    });

    test('compares by value', () {
      expect(RangeAmount(1, 2), RangeAmount(1, 2));
      expect(RangeAmount(1, 2).hashCode, RangeAmount(1, 2).hashCode);
      expect(RangeAmount(1, 2), isNot(RangeAmount(1, 3)));
    });
  });

  group('Currency', () {
    test('parses a complete payload', () {
      final currency = Currency.fromJson(currencyJson(locale: 'en_US'));

      expect(currency.code, 'USD');
      expect(currency.name, 'US Dollar');
      expect(currency.symbolNative, r'$');
      expect(currency.decimalDigits, 2);
      expect(currency.namePlural, 'US dollars');
      expect(currency.price, isTrue);
      expect(currency.locale, 'en_US');
    });

    test('accepts decimal_digits as a numeric string', () {
      expect(
          Currency.fromJson(currencyJson(decimalDigits: '3')).decimalDigits, 3);
    });

    test('accepts price as a string and defaults a missing price to false', () {
      expect(Currency.fromJson(currencyJson(price: 'true')).price, isTrue);
      expect(Currency.fromJson(currencyJson(price: 'TRUE')).price, isTrue);
      expect(Currency.fromJson(currencyJson(price: 'no')).price, isFalse);
      expect(Currency.fromJson(currencyJson(price: null)).price, isFalse);
    });

    test('throws FormatException when a required field is missing or null', () {
      for (final field in const [
        'symbol',
        'name',
        'symbol_native',
        'code',
        'emoji',
        'decimal_digits',
        'name_plural',
      ]) {
        final json = currencyJson()..remove(field);
        expect(() => Currency.fromJson(json), throwsFormatException,
            reason: 'missing $field must fail');

        final nulled = currencyJson()..[field] = null;
        expect(() => Currency.fromJson(nulled), throwsFormatException,
            reason: 'null $field must fail');
      }
    });

    test('throws FormatException for malformed decimal_digits or price', () {
      expect(() => Currency.fromJson(currencyJson(decimalDigits: 'x')),
          throwsFormatException);
      expect(() => Currency.fromJson(currencyJson(decimalDigits: 1.5)),
          throwsFormatException);
      expect(() => Currency.fromJson(currencyJson(decimalDigits: -1)),
          throwsFormatException);
      expect(() => Currency.fromJson(currencyJson(price: 42)),
          throwsFormatException);
    });

    test('rejects empty identifying fields at construction time', () {
      Currency build(
              {String symbol = r'$', String name = 'n', String code = 'C'}) =>
          Currency(
            symbol: symbol,
            name: name,
            symbolNative: r'$',
            code: code,
            emoji: '🇺🇸',
            decimalDigits: 2,
            namePlural: 'ns',
            price: true,
          );

      expect(() => build(symbol: ''), throwsArgumentError);
      expect(() => build(name: ''), throwsArgumentError);
      expect(() => build(code: ''), throwsArgumentError);
    });

    test('omits a null locale when serialising and survives a round trip', () {
      final withoutLocale = Currency.fromJson(currencyJson());
      final withLocale = Currency.fromJson(currencyJson(locale: 'es_AR'));

      expect(withoutLocale.toJson().containsKey('locale'), isFalse);
      expect(withLocale.toJson()['locale'], 'es_AR');
      expect(Currency.fromJson(withLocale.toJson()), withLocale);
    });

    test('compares by value', () {
      final a = Currency.fromJson(currencyJson());
      final b = Currency.fromJson(currencyJson());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(Currency.fromJson(currencyJson(decimalDigits: 4))));
      expect(a.toString(),
          r'Currency(symbol: $, name: US Dollar, code: USD, price: true)');
    });
  });

  group('Rating', () {
    test('returns an empty rating for the "none" sentinel', () {
      final rating = Rating.deserialized('none');

      expect(rating.totalReviews, 0);
      expect(rating.totalRating, 0.0);
      expect(rating.maxRate, 5);
      expect(rating.minRate, 1);
    });

    test('throws FormatException for an empty string', () {
      expect(() => Rating.deserialized(''), throwsFormatException);
    });

    test('parses the ["rating", {...}] tag shape', () {
      final data = jsonEncode([
        'rating',
        {'total_reviews': 7, 'total_rating': 4.5, 'days': 30}
      ]);

      final rating = Rating.deserialized(data);

      expect(rating.totalReviews, 7);
      expect(rating.totalRating, 4.5);
      expect(rating.days, 30);
      expect(rating.lastRating, 0);
      expect(rating.maxRate, 5);
      expect(rating.minRate, 1);
    });

    test('parses a flat rating object', () {
      final data = jsonEncode({
        'total_reviews': 3,
        'total_rating': 4,
        'last_rating': 5,
        'max_rate': 5,
        'min_rate': 1,
        'days': 12,
      });

      final rating = Rating.deserialized(data);

      expect(rating.totalReviews, 3);
      expect(rating.totalRating, 4.0);
      expect(rating.lastRating, 5);
      expect(rating.days, 12);
    });

    test('coerces string and mistyped numbers', () {
      final data = jsonEncode({
        'total_reviews': '3',
        'total_rating': '4.25',
        'last_rating': 5.9,
        'max_rate': 5,
        'min_rate': 1,
      });

      final rating = Rating.deserialized(data);

      expect(rating.totalReviews, 3);
      expect(rating.totalRating, 4.25);
      expect(rating.lastRating, 5);
      expect(rating.days, 0);
    });

    test('falls back to defaults for unparseable numbers', () {
      final data = jsonEncode({
        'total_reviews': 'abc',
        'total_rating': 'abc',
      });

      final rating = Rating.deserialized(data);

      expect(rating.totalReviews, 0);
      expect(rating.totalRating, 0.0);
    });

    test('falls back to empty for non-object JSON and malformed input', () {
      expect(Rating.deserialized('42').totalReviews, 0);
      expect(Rating.deserialized('not json').totalReviews, 0);
      expect(Rating.deserialized(jsonEncode(['rating'])).totalReviews, 0);
    });

    test('treats missing nested fields as their defaults', () {
      final data = jsonEncode([
        'rating',
        <String, dynamic>{'total_reviews': null}
      ]);

      final rating = Rating.deserialized(data);

      expect(rating.totalReviews, 0);
      expect(rating.totalRating, 0.0);
      expect(rating.days, 0);
    });
  });

  group('ChatRoom', () {
    test('sorts messages chronologically on construction', () {
      final room = ChatRoom(
        orderId: 'order-1',
        messages: [chatEvent('b', 200), chatEvent('a', 100)],
      );

      expect(room.messages.map((e) => e.id), ['a', 'b']);
    });

    test('rejects an empty order id', () {
      expect(
        () => ChatRoom(orderId: '', messages: []),
        throwsArgumentError,
      );
    });

    test('copy keeps the order id and can replace the messages', () {
      final room = ChatRoom(orderId: 'order-1', messages: [chatEvent('a', 1)]);

      final replaced = room.copy(messages: [chatEvent('c', 5)]);
      final unchanged = room.copy();

      expect(replaced.orderId, 'order-1');
      expect(replaced.messages.single.id, 'c');
      expect(unchanged.messages.map((e) => e.id), ['a']);
    });

    test('compares by order id and message list', () {
      final a = ChatRoom(orderId: 'o', messages: [chatEvent('a', 1)]);
      final b = ChatRoom(orderId: 'o', messages: [chatEvent('a', 1)]);
      final differentLength = ChatRoom(
        orderId: 'o',
        messages: [chatEvent('a', 1), chatEvent('b', 2)],
      );
      final differentMessage =
          ChatRoom(orderId: 'o', messages: [chatEvent('z', 1)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentLength));
      expect(a, isNot(differentMessage));
      expect(
          a, isNot(ChatRoom(orderId: 'other', messages: [chatEvent('a', 1)])));
      expect(a, equals(a));
    });

    test('renders a compact description', () {
      final room = ChatRoom(orderId: 'o', messages: [chatEvent('a', 1)]);

      expect(room.toString(), 'ChatRoom(orderId: o, messages: 1 messages)');
    });
  });
}
