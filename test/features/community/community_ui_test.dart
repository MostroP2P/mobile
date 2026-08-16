import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/config/communities.dart';
import 'package:mostro_mobile/features/community/community.dart';
import 'package:mostro_mobile/features/community/widgets/community_card.dart';
import 'package:mostro_mobile/generated/l10n.dart';

const _pubkey =
    '4444444444444444444444444444444444444444444444444444444444444444';

Community community({
  String? name,
  String? about,
  String? picture,
  bool hasTradeInfo = false,
  List<String> currencies = const [],
  int? minAmount,
  int? maxAmount,
  double? fee,
  List<SocialLink> social = const [],
  String? website,
}) =>
    Community(
      pubkey: _pubkey,
      region: 'Argentina',
      social: social,
      website: website,
      name: name,
      about: about,
      picture: picture,
      hasTradeInfo: hasTradeInfo,
      currencies: currencies,
      minAmount: minAmount,
      maxAmount: maxAmount,
      fee: fee,
    );

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Community', () {
    test('falls back to the region as the display name', () {
      expect(community().displayName, 'Argentina');
      expect(community(name: 'Mostro AR').displayName, 'Mostro AR');
    });

    test('starts with no metadata and no trade info', () {
      final c = community();

      expect(c.name, isNull);
      expect(c.about, isNull);
      expect(c.picture, isNull);
      expect(c.hasTradeInfo, isFalse);
      expect(c.currencies, isEmpty);
      expect(c.minAmount, isNull);
      expect(c.maxAmount, isNull);
      expect(c.fee, isNull);
    });

    test('is built from its static config', () {
      const config = CommunityConfig(
        pubkey: _pubkey,
        region: 'Argentina',
        social: [SocialLink(type: 'x', url: 'https://example.test/mostro')],
        website: 'https://example.test',
      );

      final c = Community.fromConfig(config);

      expect(c.pubkey, _pubkey);
      expect(c.region, 'Argentina');
      expect(c.social.single.type, 'x');
      expect(c.website, 'https://example.test');
    });

    test('copyWith layers Nostr metadata over the config', () {
      final updated = community().copyWith(
        name: 'Mostro AR',
        about: 'Argentinian community',
        picture: 'https://example.test/avatar.png',
        hasTradeInfo: true,
        currencies: const ['ARS', 'USD'],
        minAmount: 1000,
        maxAmount: 500000,
        fee: 0.006,
      );

      expect(updated.pubkey, _pubkey);
      expect(updated.region, 'Argentina');
      expect(updated.name, 'Mostro AR');
      expect(updated.about, 'Argentinian community');
      expect(updated.picture, 'https://example.test/avatar.png');
      expect(updated.hasTradeInfo, isTrue);
      expect(updated.currencies, ['ARS', 'USD']);
      expect(updated.minAmount, 1000);
      expect(updated.maxAmount, 500000);
      expect(updated.fee, 0.006);
    });

    test('copyWith keeps the existing values when nothing is given', () {
      final original = community(name: 'Mostro AR', hasTradeInfo: true);

      final copy = original.copyWith();

      expect(copy.name, 'Mostro AR');
      expect(copy.hasTradeInfo, isTrue);
    });
  });

  group('SocialLink', () {
    test('carries a type and a url', () {
      const link = SocialLink(type: 'nostr', url: 'https://example.test');

      expect(link.type, 'nostr');
      expect(link.url, 'https://example.test');
    });
  });

  group('CommunityCard', () {
    testWidgets('renders an unselected community with no metadata',
        (tester) async {
      await pump(
        tester,
        CommunityCard(
          community: community(),
          isSelected: false,
          onTap: () {},
        ),
      );

      expect(find.byType(CommunityCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a selected community with full trade info',
        (tester) async {
      await pump(
        tester,
        CommunityCard(
          community: community(
            name: 'Mostro AR',
            about: 'Argentinian community',
            hasTradeInfo: true,
            currencies: const ['ARS', 'USD', 'EUR'],
            minAmount: 500,
            maxAmount: 1500000,
            fee: 0.006,
            website: 'https://example.test',
            social: const [
              SocialLink(type: 'x', url: 'https://example.test/mostro'),
            ],
          ),
          isSelected: true,
          onTap: () {},
        ),
      );

      expect(find.byType(CommunityCard), findsOneWidget);
      expect(
          find.textContaining('Mostro AR', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders sub-1000 and over-1000 amounts', (tester) async {
      await pump(
        tester,
        CommunityCard(
          community: community(
            hasTradeInfo: true,
            currencies: const ['ARS'],
            minAmount: 100,
            maxAmount: 2000,
          ),
          isSelected: false,
          onTap: () {},
        ),
      );

      expect(find.byType(CommunityCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        CommunityCard(
          community: community(name: 'Mostro AR'),
          isSelected: false,
          onTap: () => taps++,
        ),
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(CommunityCard),
              matching: find.byType(GestureDetector),
            )
            .first,
        warnIfMissed: false,
      );
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('renders a card whose website url is malformed',
        (tester) async {
      await pump(
        tester,
        CommunityCard(
          community: community(website: ':://not a url'),
          isSelected: false,
          onTap: () {},
        ),
      );

      expect(find.byType(CommunityCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
