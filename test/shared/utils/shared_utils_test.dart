import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';
import 'package:mostro_mobile/shared/utils/auth_utils.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';
import 'package:mostro_mobile/shared/utils/mnemonic_validator.dart';
import 'package:mostro_mobile/shared/utils/text_formatting.dart';
import 'package:timeago/timeago.dart' as timeago;

/// A BIP39 test vector with a valid checksum. Not tied to any real wallet.
const _validMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

NostrEvent chatMessage(String? content) => NostrEvent(
      id: 'id',
      kind: 1059,
      content: content,
      sig: 'sig',
      pubkey: 'pubkey',
      createdAt: DateTime.utc(2026),
      tags: const [],
    );

/// Pumps a localized MaterialApp so helpers that read `Theme.of` or
/// `Localizations.localeOf` resolve, and returns its BuildContext.
Future<BuildContext> pumpContext(WidgetTester tester, {Locale? locale}) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('es'), Locale('it')],
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

void main() {
  setUpAll(() {
    timeago.setLocaleMessages('es', timeago.EsMessages());
    timeago.setLocaleMessages('it', timeago.ItMessages());
  });

  group('CurrencyUtils.formatSats', () {
    test('inserts thousand separators', () {
      expect(CurrencyUtils.formatSats(1000000), '1,000,000');
      expect(CurrencyUtils.formatSats(1234), '1,234');
    });

    test('leaves small amounts untouched', () {
      expect(CurrencyUtils.formatSats(0), '0');
      expect(CurrencyUtils.formatSats(999), '999');
    });
  });

  group('CurrencyUtils flag helpers', () {
    test('builds a regional-indicator flag from a country code', () {
      expect(CurrencyUtils.getFlagEmoji('US'), '🇺🇸');
      expect(CurrencyUtils.getFlagEmoji('ar'), '🇦🇷');
    });

    test('derives the flag from the first two letters of a currency code', () {
      expect(CurrencyUtils.getFlagFromCurrency('USD'), '🇺🇸');
      expect(CurrencyUtils.getFlagFromCurrency('ars'), '🇦🇷');
    });

    test('prefers the emoji carried by the currency data', () {
      final data = {
        'VES': Currency(
          symbol: 'Bs',
          name: 'Bolívar',
          symbolNative: 'Bs',
          code: 'VES',
          emoji: '🇻🇪',
          decimalDigits: 2,
          namePlural: 'bolívares',
          price: true,
        ),
      };

      expect(CurrencyUtils.getFlagFromCurrencyData('ves', data), '🇻🇪');
    });

    test('falls back to the derived flag when there is no currency data', () {
      expect(CurrencyUtils.getFlagFromCurrencyData('USD', null), '🇺🇸');
    });

    test('falls back to a white flag for an unknown currency', () {
      expect(CurrencyUtils.getFlagFromCurrencyData('XYZ', const {}), '🏳️');
    });

    test('falls back to a white flag when the emoji is empty', () {
      final data = {
        'AAA': Currency(
          symbol: 'A',
          name: 'A',
          symbolNative: 'A',
          code: 'AAA',
          emoji: '',
          decimalDigits: 0,
          namePlural: 'As',
          price: false,
        ),
      };

      expect(CurrencyUtils.getFlagFromCurrencyData('AAA', data), '🏳️');
    });
  });

  group('validateMnemonic', () {
    test('accepts a valid 12-word mnemonic', () {
      expect(validateMnemonic(_validMnemonic), isTrue);
    });

    test('tolerates surrounding whitespace', () {
      expect(validateMnemonic('  $_validMnemonic  '), isTrue);
    });

    test('rejects an empty or blank input', () {
      expect(validateMnemonic(''), isFalse);
      expect(validateMnemonic('   '), isFalse);
    });

    test('rejects a mnemonic with a broken checksum', () {
      expect(
        validateMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon',
        ),
        isFalse,
      );
    });

    test('rejects words outside the BIP39 wordlist', () {
      expect(validateMnemonic('not a real mnemonic phrase at all here ok'),
          isFalse);
    });

    test('rejects an invalid word count', () {
      expect(validateMnemonic('abandon about'), isFalse);
    });
  });

  group('AuthUtils (alpha stubs)', () {
    test('savePrivateKeyAndPin completes without storing anything', () async {
      await expectLater(
        AuthUtils.savePrivateKeyAndPin('privkey', '1234'),
        completes,
      );
    });

    test('getPrivateKey returns null', () async {
      expect(await AuthUtils.getPrivateKey(), isNull);
    });

    test('the unimplemented operations throw UnimplementedError', () {
      expect(AuthUtils.verifyPin('1234'), throwsUnimplementedError);
      expect(AuthUtils.deleteCredentials(), throwsUnimplementedError);
      expect(AuthUtils.enableBiometrics(), throwsUnimplementedError);
      expect(AuthUtils.isBiometricsEnabled(), throwsUnimplementedError);
    });
  });

  group('MessageTypeUtils', () {
    test('detects an encrypted image payload', () {
      final message =
          chatMessage(jsonEncode({'type': 'image_encrypted', 'url': 'u'}));

      expect(MessageTypeUtils.isEncryptedImageMessage(message), isTrue);
      expect(MessageTypeUtils.isEncryptedFileMessage(message), isFalse);
      expect(MessageTypeUtils.getMessageType(message),
          MessageContentType.encryptedImage);
    });

    test('detects an encrypted file payload', () {
      final message =
          chatMessage(jsonEncode({'type': 'file_encrypted', 'url': 'u'}));

      expect(MessageTypeUtils.isEncryptedFileMessage(message), isTrue);
      expect(MessageTypeUtils.isEncryptedImageMessage(message), isFalse);
      expect(MessageTypeUtils.getMessageType(message),
          MessageContentType.encryptedFile);
    });

    test('treats plain text as a text message', () {
      final message = chatMessage('just a message');

      expect(MessageTypeUtils.isEncryptedImageMessage(message), isFalse);
      expect(MessageTypeUtils.isEncryptedFileMessage(message), isFalse);
      expect(MessageTypeUtils.getMessageType(message), MessageContentType.text);
    });

    test('treats null content as a text message', () {
      final message = chatMessage(null);

      expect(MessageTypeUtils.getMessageType(message), MessageContentType.text);
    });

    test('treats malformed JSON as a text message', () {
      final message = chatMessage('{not valid json');

      expect(MessageTypeUtils.isEncryptedImageMessage(message), isFalse);
      expect(MessageTypeUtils.isEncryptedFileMessage(message), isFalse);
      expect(MessageTypeUtils.getMessageType(message), MessageContentType.text);
    });

    test('treats a JSON object with another type as a text message', () {
      final message = chatMessage(jsonEncode({'type': 'something_else'}));

      expect(MessageTypeUtils.getMessageType(message), MessageContentType.text);
    });
  });

  group('DateTimeExtensions', () {
    test('timeAgoDefault formats in English by default', () {
      final moment = DateTime.now().subtract(const Duration(hours: 2));

      expect(moment.timeAgoDefault(), contains('hour'));
    });

    test('timeAgoDefault honours an explicit locale', () {
      final moment = DateTime.now().subtract(const Duration(hours: 2));

      expect(moment.timeAgoDefault('es'), contains('hora'));
    });

    testWidgets('timeAgoWithLocale follows the widget locale', (tester) async {
      final context = await pumpContext(tester, locale: const Locale('es'));
      final moment = DateTime.now().subtract(const Duration(hours: 2));

      expect(moment.timeAgoWithLocale(context), contains('hora'));
    });

    testWidgets('timeAgoWithLocale accepts an explicit locale override',
        (tester) async {
      final context = await pumpContext(tester, locale: const Locale('es'));
      final moment = DateTime.now().subtract(const Duration(hours: 2));

      expect(moment.timeAgoWithLocale(context, 'en'), contains('hour'));
    });

    testWidgets('preciseTimeAgo reports seconds per locale', (tester) async {
      final context = await pumpContext(tester, locale: const Locale('en'));
      final moment = DateTime.now().subtract(const Duration(seconds: 10));

      expect(moment.preciseTimeAgo(context), contains('seconds ago'));
      expect(moment.preciseTimeAgo(context, 'es'), startsWith('hace '));
      expect(moment.preciseTimeAgo(context, 'es'), contains('segundos'));
      expect(moment.preciseTimeAgo(context, 'it'), contains('secondi fa'));
    });

    testWidgets('preciseTimeAgo delegates to timeago past one minute',
        (tester) async {
      final context = await pumpContext(tester, locale: const Locale('en'));
      final moment = DateTime.now().subtract(const Duration(minutes: 5));

      expect(moment.preciseTimeAgo(context), isNot(contains('seconds ago')));
    });
  });

  group('formatTextWithBoldUsernames', () {
    testWidgets('returns a single span when no handle is present',
        (tester) async {
      final context = await pumpContext(tester);

      final span = formatTextWithBoldUsernames('no handles here', context);

      expect(span.children!.cast<TextSpan>().single.text, 'no handles here');
      expect(
        span.children!.cast<TextSpan>().single.style?.fontWeight,
        isNot(FontWeight.bold),
      );
    });

    testWidgets('bolds a handle surrounded by plain text', (tester) async {
      final context = await pumpContext(tester);

      final span =
          formatTextWithBoldUsernames('trade with cyber-prague today', context);
      final children = span.children!.cast<TextSpan>();

      expect(children.map((s) => s.text),
          ['trade with ', 'cyber-prague', ' today']);
      expect(children[1].style?.fontWeight, FontWeight.bold);
      expect(children[0].style?.fontWeight, isNot(FontWeight.bold));
    });

    testWidgets('bolds a handle at the start of the text', (tester) async {
      final context = await pumpContext(tester);

      final span =
          formatTextWithBoldUsernames('anonymous-finney sent fiat', context);
      final children = span.children!.cast<TextSpan>();

      expect(children.first.text, 'anonymous-finney');
      expect(children.first.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('bolds every handle in the text', (tester) async {
      final context = await pumpContext(tester);

      final span = formatTextWithBoldUsernames(
          'cyber-prague and anonymous-finney', context);
      final bold = span.children!
          .cast<TextSpan>()
          .where((s) => s.style?.fontWeight == FontWeight.bold)
          .map((s) => s.text);

      expect(bold, ['cyber-prague', 'anonymous-finney']);
    });
  });
}
