import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_content.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// The resolution banner is rendered from the message action plus the local
/// role alone: the app never reads the wallet or the escrow. It must therefore
/// attribute the outcome to the admin and ask the user to confirm, rather than
/// state that funds moved.

Widget _wrap(DisputeData dispute) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: DisputeStatusContent(dispute: dispute)),
      ),
    );

DisputeData _resolved({
  required String action,
  required UserRole userRole,
  String status = 'resolved',
}) =>
    DisputeData(
      disputeId: 'dispute-1',
      status: status,
      descriptionKey: DisputeDescriptionKey.resolved,
      createdAt: DateTime(2026, 1, 1),
      userRole: userRole,
      action: action,
    );

String _renderedText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  return texts.join(' ');
}

void main() {
  testWidgets('settled resolution does not tell the buyer the sats arrived',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_resolved(action: 'admin-settled', userRole: UserRole.buyer)),
    );
    await tester.pumpAndSettle();

    final rendered = _renderedText(tester);

    expect(rendered, contains('admin'),
        reason: 'the outcome must be attributed to who decided it');
    expect(rendered, contains('Check your wallet'),
        reason: 'the user must be pointed at the only authoritative source');
    expect(rendered, isNot(contains('you received the sats')),
        reason: 'the app never observed the funds moving');
  });

  testWidgets('canceled resolution does not assert the refund to the seller',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_resolved(
        action: 'admin-canceled',
        userRole: UserRole.seller,
        status: 'seller-refunded',
      )),
    );
    await tester.pumpAndSettle();

    final rendered = _renderedText(tester);

    expect(rendered, contains('Check your wallet'));
    expect(rendered, isNot(contains('refunded you')),
        reason: 'the app never observed the refund');
  });

  testWidgets('settled resolution does not assert what the counterparty got',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_resolved(action: 'admin-settled', userRole: UserRole.seller)),
    );
    await tester.pumpAndSettle();

    expect(_renderedText(tester), isNot(contains('received the sats')));
  });

  testWidgets('canceled resolution does not assert the seller was refunded',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_resolved(action: 'admin-canceled', userRole: UserRole.buyer)),
    );
    await tester.pumpAndSettle();

    expect(_renderedText(tester), isNot(contains('seller was refunded')));
  });
}
