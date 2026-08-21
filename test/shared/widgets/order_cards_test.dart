import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _currencies = <String, Currency>{
  'USD': Currency(
    symbol: r'$',
    name: 'US Dollar',
    symbolNative: r'$',
    code: 'USD',
    emoji: '🇺🇸',
    decimalDigits: 2,
    namePlural: 'US dollars',
    price: true,
  ),
};

/// Holds a fixed [Settings] so cards reading `settingsProvider` can be pumped
/// without touching storage. Nothing calls `init()`, so the preferences
/// instance is never used.
class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(Settings settings) : super(SharedPreferencesAsync()) {
    state = settings;
  }
}

/// Pumps [child] with the currency catalogue stubbed out, so cards that read
/// `currencyCodesProvider` resolve without hitting the exchange service.
Future<void> pumpCard(
  WidgetTester tester,
  Widget child, {
  Map<String, Currency>? currencies,
  Settings? settings,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodesProvider
            .overrideWith((ref) async => currencies ?? _currencies),
        if (settings != null)
          settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('OrderAmountCard', () {
    testWidgets('renders the title, amount and currency', (tester) async {
      await pumpCard(
        tester,
        const OrderAmountCard(
          title: 'You receive',
          amount: '50,000',
          currency: 'USD',
        ),
      );

      expect(find.text('You receive'), findsOneWidget);
      expect(find.textContaining('50,000', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the optional price and premium lines', (tester) async {
      await pumpCard(
        tester,
        const OrderAmountCard(
          title: 'You pay',
          amount: '100',
          currency: 'USD',
          priceText: 'Market price',
          premiumText: '+3%',
        ),
      );

      expect(find.textContaining('Market price', findRichText: true),
          findsWidgets);
      expect(find.textContaining('+3%'), findsWidgets);
    });

    testWidgets('renders while the currency catalogue is still loading',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodesProvider.overrideWith(
              (ref) => Future<Map<String, Currency>>.delayed(
                const Duration(seconds: 5),
                () => _currencies,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(
              body: OrderAmountCard(
                title: 'You receive',
                amount: '1',
                currency: 'USD',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OrderAmountCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('falls back gracefully for an unknown currency code',
        (tester) async {
      await pumpCard(
        tester,
        const OrderAmountCard(
          title: 'You receive',
          amount: '1',
          currency: 'XYZ',
        ),
      );

      expect(find.byType(OrderAmountCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PaymentMethodCard', () {
    testWidgets('renders the payment method', (tester) async {
      await pumpCard(
          tester, const PaymentMethodCard(paymentMethod: 'Wire transfer'));

      expect(find.textContaining('Wire transfer'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an empty payment method without throwing',
        (tester) async {
      await pumpCard(tester, const PaymentMethodCard(paymentMethod: ''));

      expect(find.byType(PaymentMethodCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CreatedDateCard', () {
    testWidgets('renders the supplied date text', (tester) async {
      await pumpCard(tester, const CreatedDateCard(createdDate: '16 Aug 2026'));

      expect(find.textContaining('16 Aug 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderIdCard', () {
    testWidgets('renders the order id', (tester) async {
      await pumpCard(tester, const OrderIdCard(orderId: 'order-1234'));

      expect(find.textContaining('order-1234'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderShareLinkCard', () {
    const pubkey =
        '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

    Settings settingsWith(List<String> relays) => Settings(
          relays: relays,
          fullPrivacyMode: false,
          mostroPublicKey: pubkey,
        );

    testWidgets('renders a link carrying the order, relays and instance',
        (tester) async {
      await pumpCard(
        tester,
        const OrderShareLinkCard(orderId: 'order-1234'),
        settings: settingsWith(const ['wss://relay.mostro.network']),
      );

      expect(
        find.text(
          'mostro:order-1234?relays=wss://relay.mostro.network&mostro=$pubkey',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('copies that link to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpCard(
        tester,
        const OrderShareLinkCard(orderId: 'order-1234'),
        settings: settingsWith(const ['wss://relay.mostro.network']),
      );

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(
        copied,
        'mostro:order-1234?relays=wss://relay.mostro.network&mostro=$pubkey',
      );
    });

    testWidgets('renders nothing when no relay can resolve the order',
        (tester) async {
      await pumpCard(
        tester,
        const OrderShareLinkCard(orderId: 'order-1234'),
        settings: settingsWith(const []),
      );

      expect(find.textContaining('mostro:'), findsNothing);
      expect(find.byIcon(Icons.copy), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CreatorReputationCard', () {
    testWidgets('renders rating, review count and account age', (tester) async {
      await pumpCard(
        tester,
        const CreatorReputationCard(rating: 4.5, reviews: 12, days: 90),
      );

      expect(find.byType(CreatorReputationCard), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a brand new creator with no reviews', (tester) async {
      await pumpCard(
        tester,
        const CreatorReputationCard(rating: 0, reviews: 0, days: 0),
      );

      expect(find.byType(CreatorReputationCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a perfect rating', (tester) async {
      await pumpCard(
        tester,
        const CreatorReputationCard(rating: 5, reviews: 999, days: 1000),
      );

      expect(find.byType(CreatorReputationCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NotificationMessageCard', () {
    testWidgets('renders the message with the default icon', (tester) async {
      await pumpCard(
        tester,
        const NotificationMessageCard(message: 'Waiting for the seller'),
      );

      expect(find.text('Waiting for the seller'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('honours a custom icon and colour', (tester) async {
      await pumpCard(
        tester,
        const NotificationMessageCard(
          message: 'Something went wrong',
          icon: Icons.error,
          iconColor: Colors.red,
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.error)).color, Colors.red);
    });
  });
}
