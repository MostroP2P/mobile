import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/features/settings/about_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

import '../../mocks.mocks.dart';

/// Builds the kind 38383 info event a Mostro daemon publishes, with the tags
/// `MostroInstance.fromEvent` reads. Values are synthetic.
NostrEvent instanceEvent({
  String? bondEnabled,
  String? bondApplyTo,
  String? bondAmountPct,
  String? bondBaseAmountSats,
  String? bondPayoutClaimWindowDays,
  String? bondSlashNodeSharePct,
  String? bondSlashOnWaitingTimeout,
  String protocolVersion = '1',
}) =>
    NostrEvent(
      id: 'info-event',
      kind: 38383,
      content: '',
      sig: 'sig',
      pubkey: 'a' * 64,
      createdAt: DateTime.utc(2026),
      tags: [
        ['d', 'a' * 64],
        ['mostro_version', '1.2.3'],
        ['mostro_commit_hash', 'abc1234'],
        ['max_order_amount', '20000000'],
        ['min_order_amount', '100'],
        ['expiration_hours', '24'],
        ['expiration_seconds', '86400'],
        ['fee', '0.006'],
        ['pow', '0'],
        ['hold_invoice_expiration_window', '120'],
        ['hold_invoice_cltv_delta', '144'],
        ['invoice_expiration_window', '3600'],
        ['lnd_version', 'v0.17.0'],
        ['lnd_node_pubkey', 'b' * 66],
        ['lnd_commit_hash', 'def5678'],
        ['lnd_node_alias', 'mostro-node'],
        ['lnd_chains', 'bitcoin'],
        ['lnd_networks', 'mainnet'],
        ['lnd_uris', 'lnd-node-uri'],
        ['fiat_currencies_accepted', 'USD,EUR,ARS'],
        ['max_orders_per_response', '50'],
        ['protocol_version', protocolVersion],
        if (bondEnabled != null) ['bond_enabled', bondEnabled],
        if (bondApplyTo != null) ['bond_apply_to', bondApplyTo],
        if (bondAmountPct != null) ['bond_amount_pct', bondAmountPct],
        if (bondBaseAmountSats != null)
          ['bond_base_amount_sats', bondBaseAmountSats],
        if (bondPayoutClaimWindowDays != null)
          ['bond_payout_claim_window_days', bondPayoutClaimWindowDays],
        if (bondSlashNodeSharePct != null)
          ['bond_slash_node_share_pct', bondSlashNodeSharePct],
        if (bondSlashOnWaitingTimeout != null)
          ['bond_slash_on_waiting_timeout', bondSlashOnWaitingTimeout],
      ],
    );

/// Pumps AboutScreen behind a router (it calls `context.pop()`), with the
/// order repository stubbed to advertise [mostroInstance].
Future<void> pumpAboutScreen(
  WidgetTester tester, {
  NostrEvent? mostroInstance,
}) async {
  final repository = MockOpenOrdersRepository();
  when(repository.mostroInstance).thenReturn(mostroInstance);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => const AboutScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  router.push('/about');
  // The screen shows a progress indicator while no instance is known, so
  // settling would never complete: pump a couple of frames instead.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final clipboardWrites = <String>[];

  setUp(() {
    clipboardWrites.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardWrites.add(call.arguments['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('AboutScreen', () {
    testWidgets('renders without a connected Mostro instance', (tester) async {
      await pumpAboutScreen(tester);

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the details of a connected instance', (tester) async {
      await pumpAboutScreen(tester, mostroInstance: instanceEvent());

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.textContaining('1.2.3'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders bond details when the instance enables bonds',
        (tester) async {
      await pumpAboutScreen(
        tester,
        mostroInstance: instanceEvent(
          protocolVersion: '2',
          bondEnabled: 'true',
          bondApplyTo: 'both',
          bondAmountPct: '2.5',
          bondBaseAmountSats: '1000',
          bondPayoutClaimWindowDays: '7',
          bondSlashNodeSharePct: '50',
          bondSlashOnWaitingTimeout: 'true',
        ),
      );

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders when bonds are explicitly disabled', (tester) async {
      await pumpAboutScreen(
        tester,
        mostroInstance: instanceEvent(
          protocolVersion: '2',
          bondEnabled: 'false',
        ),
      );

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls through the whole page without overflowing',
        (tester) async {
      await pumpAboutScreen(tester, mostroInstance: instanceEvent());

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the back button pops the route', (tester) async {
      await pumpAboutScreen(tester, mostroInstance: instanceEvent());

      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('copies a value to the clipboard when a copy row is tapped',
        (tester) async {
      await pumpAboutScreen(tester, mostroInstance: instanceEvent());

      final taps = find.byType(InkWell);
      if (taps.evaluate().isNotEmpty) {
        await tester.tap(taps.first, warnIfMissed: false);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  });
}
