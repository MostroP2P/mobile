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

Widget _wrap(DisputeData dispute, {Locale locale = const Locale('en')}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
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

  // The wording is a security property, not a copy detail: a locale that
  // reverts to asserting fund movement puts those users back where they
  // started.
  group('localized resolutions attribute the outcome instead of asserting it',
      () {
    // (admin attribution, wallet, verb of confirmation, phrase unique to the
    // old wording that announced the order as already completed).
    const locales = {
      'en': ('admin', 'Check your wallet', 'confirm', 'completed successfully'),
      'es': (
        'administrador',
        'Revisa tu billetera',
        'confirmar',
        'se completó exitosamente'
      ),
      'it': (
        'amministratore',
        'Controlla il tuo wallet',
        'confermare',
        'completato con successo'
      ),
      'pt': (
        'administrador',
        'Verifique sua carteira',
        'confirmar',
        'concluída com sucesso'
      ),
      'de': (
        'Administrator',
        'Überprüfe deine Wallet',
        'bestätigen',
        'erfolgreich abgeschlossen'
      ),
      'fr': (
        'administrateur',
        'Vérifiez votre portefeuille',
        'confirmer',
        'terminée avec succès'
      ),
    };

    /// The variants where the user is the one owed money. Only these may talk
    /// about the wallet, and they must ask rather than announce.
    const awaitingFunds = [
      ('admin-settled', UserRole.buyer),
      ('admin-canceled', UserRole.seller),
    ];
    const notAwaitingFunds = [
      ('admin-settled', UserRole.seller),
      ('admin-canceled', UserRole.buyer),
    ];

    locales.forEach((code, expectations) {
      final (adminWord, wallet, confirms, oldWording) = expectations;

      testWidgets(code, (tester) async {
        Future<String> render(String action, UserRole role) async {
          await tester.pumpWidget(
            _wrap(
              _resolved(action: action, userRole: role),
              locale: Locale(code),
            ),
          );
          await tester.pumpAndSettle();
          return _renderedText(tester);
        }

        for (final (action, role) in [...awaitingFunds, ...notAwaitingFunds]) {
          final rendered = await render(action, role);

          expect(rendered, contains(adminWord),
              reason: '$code/$action/${role.name} must attribute the outcome '
                  'to the admin who decided it');
          expect(rendered, isNot(contains(oldWording)),
              reason: '$code/$action/${role.name} must not go back to stating '
                  'the order as settled fact');
        }

        for (final (action, role) in awaitingFunds) {
          final rendered = await render(action, role);

          expect(rendered, contains(wallet),
              reason: '$code/$action/${role.name} must point the user at '
                  'their wallet');
          expect(rendered, contains(confirms),
              reason: '$code/$action/${role.name} must ask the user to '
                  'confirm, not announce receipt');
        }
      });
    });
  });
}
