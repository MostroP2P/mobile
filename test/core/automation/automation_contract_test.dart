// Automation contract tests: every semantic identifier Mortsom relies on
// must stay present, unique and namespaced. Removing or renaming one is a
// contract change (see docs/automation-contract.md) and must fail here.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/core/test_environment.dart';
import 'package:mostro_mobile/features/community/community.dart';
import 'package:mostro_mobile/features/community/widgets/community_card.dart';
import 'package:mostro_mobile/features/key_manager/import_mnemonic_dialog.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/add_order_button.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';
import 'package:mostro_mobile/shared/widgets/test_environment_banner.dart';

/// Every static identifier declared on [AutomationIds].
const List<String> staticIds = [
  AutomationIds.envMarker,
  AutomationIds.appBarDrawer,
  AutomationIds.appBarBack,
  AutomationIds.navOrderBook,
  AutomationIds.navTrades,
  AutomationIds.navChat,
  AutomationIds.drawerAccount,
  AutomationIds.drawerSettings,
  AutomationIds.drawerAbout,
  AutomationIds.onboardingBack,
  AutomationIds.onboardingSkip,
  AutomationIds.onboardingNext,
  AutomationIds.onboardingDone,
  AutomationIds.communityCustomNode,
  AutomationIds.communityDone,
  AutomationIds.communitySkip,
  AutomationIds.keysGenerate,
  AutomationIds.keysGenerateConfirm,
  AutomationIds.keysImport,
  AutomationIds.keysImportMnemonic,
  AutomationIds.keysImportConfirm,
  AutomationIds.keysImportCancel,
  AutomationIds.keysSeedReveal,
  AutomationIds.keysSeedText,
  AutomationIds.keysPublicKey,
  AutomationIds.settingsMostroNode,
  AutomationIds.settingsMostroNodePubkey,
  AutomationIds.settingsWallet,
  AutomationIds.settingsRelaysAdd,
  AutomationIds.settingsRelaysAddUrl,
  AutomationIds.settingsRelaysAddConfirm,
  AutomationIds.settingsRelaysAddCancel,
  AutomationIds.nodeAddCustom,
  AutomationIds.nodeCustomPubkey,
  AutomationIds.nodeCustomName,
  AutomationIds.nodeCustomConfirm,
  AutomationIds.nodeCustomCancel,
  AutomationIds.walletNwcUri,
  AutomationIds.walletNwcConnect,
  AutomationIds.walletConnection,
  AutomationIds.walletSettingsConnect,
  AutomationIds.walletSettingsDisconnect,
  AutomationIds.orderBookTabBuy,
  AutomationIds.orderBookTabSell,
  AutomationIds.orderAddFab,
  AutomationIds.orderAddBuy,
  AutomationIds.orderAddSell,
  AutomationIds.orderCreateCurrency,
  AutomationIds.orderCreateFiatAmount,
  AutomationIds.orderCreateFiatAmountMax,
  AutomationIds.orderCreatePaymentMethod,
  AutomationIds.orderCreatePriceType,
  AutomationIds.orderCreateSatsAmount,
  AutomationIds.orderCreateSubmit,
  AutomationIds.orderCreateCancel,
  AutomationIds.orderConfirmHome,
  AutomationIds.orderTakeConfirm,
  AutomationIds.orderTakeClose,
  AutomationIds.orderTakeAmount,
  AutomationIds.orderTakeAmountConfirm,
  AutomationIds.orderId,
  AutomationIds.orderStatus,
  AutomationIds.tradesItemStatus,
  AutomationIds.tradePayInvoice,
  AutomationIds.tradeAddInvoice,
  AutomationIds.tradeTakeSell,
  AutomationIds.tradeTakeBuy,
  AutomationIds.tradeFiatSent,
  AutomationIds.tradeRelease,
  AutomationIds.tradeReleaseConfirm,
  AutomationIds.tradeCancel,
  AutomationIds.tradeCancelConfirm,
  AutomationIds.tradeDispute,
  AutomationIds.tradeDisputeConfirm,
  AutomationIds.invoiceText,
  AutomationIds.invoiceSubmit,
  AutomationIds.invoiceCancel,
  AutomationIds.invoiceNwcGenerate,
  AutomationIds.invoiceNwcConfirm,
  AutomationIds.invoiceNwcText,
  AutomationIds.payInvoiceText,
  AutomationIds.payNwc,
  AutomationIds.payCancel,
];

Widget harness(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  group('AutomationIds', () {
    test('are unique and namespaced', () {
      final pattern = RegExp(r'^[a-z][a-zA-Z0-9_]*(\.[a-z][a-zA-Z0-9_]*)+$');
      expect(staticIds.toSet().length, staticIds.length,
          reason: 'duplicate id');
      for (final id in staticIds) {
        expect(pattern.hasMatch(id), isTrue, reason: '$id is not namespaced');
      }
    });

    test('dynamic helpers keep their documented prefixes', () {
      expect(
          AutomationIds.communityCard('abc'), 'onboarding.community.card.abc');
      expect(AutomationIds.nodeItem('abc'), 'node.item.abc');
      expect(AutomationIds.settingsRelayItem('ws://x'),
          'settings.relays.item.ws://x');
      // One relay, one identifier: the trailing slash must not fork it, and
      // each delete control is keyed by its own relay.
      expect(AutomationIds.settingsRelayItem('ws://x/'),
          AutomationIds.settingsRelayItem('ws://x'));
      expect(AutomationIds.settingsRelayDelete('ws://x/'),
          'settings.relays.item.ws://x.delete');
      expect(AutomationIds.settingsRelayDelete('ws://y'),
          isNot(AutomationIds.settingsRelayDelete('ws://x')));
      expect(AutomationIds.orderBookItem('o1'), 'order.book.item.o1');
      expect(AutomationIds.tradesItem('o1'), 'trades.item.o1');
      expect(
          AutomationIds.tradeAction('fiatSent'), AutomationIds.tradeFiatSent);
      expect(AutomationIds.tradeAction('release'), AutomationIds.tradeRelease);
      expect(AutomationIds.tradeAction('payInvoice'),
          AutomationIds.tradePayInvoice);
      expect(
          AutomationIds.tradeAction('takeSell'), AutomationIds.tradeTakeSell);
      expect(AutomationIds.orderCreateCurrencyOption('USD'),
          'order.create.currency.USD');
    });
  });

  group('TestEnvironment', () {
    tearDown(TestEnvironment.disarm);

    test('is disabled unless armed and compiled with the define', () {
      // Stated against the compile-time define rather than a fixed false, so
      // the suite is correct whether or not it carries MORTSOM_TEST_ENV.
      expect(TestEnvironment.enabled, isFalse);
      TestEnvironment.arm();
      expect(TestEnvironment.enabled, TestEnvironment.defineEnabled);
      expect(TestEnvironment.disableBootstrapFallback,
          TestEnvironment.defineEnabled);
      expect(
          TestEnvironment.allowInsecureRelays, TestEnvironment.defineEnabled);
    });

    test('does not allow insecure relays on its own when not armed', () {
      // The debug-build allowance lives in Config.allowInsecureRelays; the
      // test-environment flag itself must stay tied to `enabled`.
      expect(TestEnvironment.enabled, isFalse);
      expect(TestEnvironment.allowInsecureRelays, isFalse);
    });

    test('Config.allowInsecureRelays follows the build mode when not armed',
        () {
      // `flutter test` is a non-release build, so the allowance comes from
      // the build mode alone, never from the test environment.
      expect(TestEnvironment.enabled, isFalse);
      expect(Config.allowInsecureRelays, !kReleaseMode);
      expect(Config.allowInsecureRelays, isTrue);
    });

    test('parses relay lists', () {
      expect(TestEnvironment.parseRelays(' ws://10.0.2.2:7000, ,wss://x '),
          ['ws://10.0.2.2:7000', 'wss://x']);
      expect(TestEnvironment.parseRelays(''), isEmpty);
    });
  });

  group('AutomationId widget', () {
    testWidgets('exposes the identifier and merges the label', (tester) async {
      await tester.pumpWidget(harness(
        ElevatedButton(onPressed: () {}, child: const Text('Go'))
            .withAutomationId('demo.control'),
      ));

      // `containsSemantics` (rather than `SemanticsData.flagsCollection`)
      // keeps this readable on the Flutter version CI pins; migrate to
      // `isSemantics` when the pin moves past 3.40.
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('demo.control')),
        containsSemantics(label: 'Go', isButton: true),
      );
    });

    testWidgets('merged text fields stay editable through accessibility',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(harness(
        TextField(controller: controller).withAutomationId('demo.field'),
      ));

      // Tapping the merged node focuses the field, as a driver's tap would.
      await tester.tap(find.bySemanticsIdentifier('demo.field'));
      await tester.pump();
      final node =
          tester.getSemantics(find.bySemanticsIdentifier('demo.field'));
      expect(
        node,
        containsSemantics(
          isTextField: true,
          isFocused: true,
          hasSetTextAction: true,
        ),
      );

      tester.semantics.performAction(
        find.semantics.byPredicate((n) => n.identifier == 'demo.field'),
        SemanticsAction.setText,
        args: 'ws://10.0.2.2:7000',
      );
      await tester.pump();
      expect(controller.text, 'ws://10.0.2.2:7000');
    });

    testWidgets('container mode keeps an explicit state label', (tester) async {
      await tester.pumpWidget(harness(
        const Text('Wallet')
            .withAutomationId('demo.state', merge: false, label: 'connected'),
      ));

      final semantics =
          tester.getSemantics(find.bySemanticsIdentifier('demo.state'));
      expect(semantics.label, 'connected');
      expect(semantics.getSemanticsData().label, 'connected');
    });
  });

  group('contract identifiers on real widgets', () {
    testWidgets('order creation entry points', (tester) async {
      await tester.pumpWidget(harness(const AddOrderButton()));
      expect(find.bySemanticsIdentifier(AutomationIds.orderAddFab),
          findsOneWidget);
      // Buy/sell are hidden (opacity 0) until the menu opens.
      await tester.tap(find.bySemanticsIdentifier(AutomationIds.orderAddFab));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier(AutomationIds.orderAddBuy),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(AutomationIds.orderAddSell),
          findsOneWidget);
    });

    testWidgets('invoice entry', (tester) async {
      await tester.pumpWidget(harness(AddLightningInvoiceWidget(
        controller: TextEditingController(),
        onSubmit: () {},
        onCancel: () {},
        amount: 1000,
        fiatAmount: '10',
        fiatCode: 'USD',
        orderId: 'order-1',
      )));
      expect(find.bySemanticsIdentifier(AutomationIds.invoiceText),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(AutomationIds.invoiceSubmit),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(AutomationIds.invoiceCancel),
          findsOneWidget);
    });

    testWidgets('mnemonic import dialog', (tester) async {
      await tester.pumpWidget(harness(const ImportMnemonicDialog()));
      expect(find.bySemanticsIdentifier(AutomationIds.keysImportMnemonic),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(AutomationIds.keysImportConfirm),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(AutomationIds.keysImportCancel),
          findsOneWidget);
    });

    testWidgets('community card carries its pubkey', (tester) async {
      const community = Community(pubkey: 'deadbeef', region: 'Test');
      await tester.pumpWidget(harness(CommunityCard(
          community: community, isSelected: false, onTap: () {})));
      expect(
          find.bySemanticsIdentifier(AutomationIds.communityCard('deadbeef')),
          findsOneWidget);
    });

    testWidgets('order id readout', (tester) async {
      await tester.pumpWidget(harness(const OrderIdCard(orderId: 'order-123')));
      final data = tester
          .getSemantics(find.bySemanticsIdentifier(AutomationIds.orderId))
          .getSemanticsData();
      expect(data.label, 'order-123');
    });

    testWidgets('environment banner is absent outside the test environment',
        (tester) async {
      await tester
          .pumpWidget(harness(const TestEnvironmentBanner(child: Text('app'))));
      expect(find.bySemanticsIdentifier(AutomationIds.envMarker), findsNothing);
      expect(find.text('app'), findsOneWidget);
    });
  });
}
