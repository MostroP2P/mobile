import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/features/reputation/screens/reputation_screen.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

import '../../mocks.mocks.dart';

final Map<String, dynamic> vectors = jsonDecode(
  File('test/fixtures/reputation_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

class _Settings extends SettingsNotifier {
  _Settings(bool fullPrivacy) : super(MockSharedPreferencesAsync()) {
    state = Settings(
        relays: const [],
        fullPrivacyMode: fullPrivacy,
        mostroPublicKey: 'node');
  }
}

class _FakeService implements ReputationService {
  int exports = 0;
  final List<String?> rebinds = [];
  String? refuseWith;
  final String json;
  final int clock;

  _FakeService(this.json, this.clock);

  @override
  Future<ReputationAttestation> exportReputation(
      {String? destination, String? rebind}) async {
    exports++;
    rebinds.add(rebind);
    if (refuseWith != null) throw ReputationException(refuseWith!);
    return ReputationAttestation.parse(json, now: clock);
  }

  @override
  String signRebind({required String issuer, required String newIdentity}) =>
      'rebind:$issuer:$newIdentity';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final secrets = vectors['secret_keys'] as Map<String, dynamic>;
  final identity = NostrKeyPairs(private: secrets['identity'] as String);
  final issuer = NostrKeyPairs(private: secrets['issuer-a'] as String).public;
  final valid = vectors['attestation']['valid']['json'] as String;
  final now = vectors['context']['now'] as int;

  Future<_FakeService> pump(
    WidgetTester tester, {
    String? nodeIssuer,
    List<String>? importIssuers = const [],
    bool fullPrivacy = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeService(valid, now);
    final keys = MockKeyManager();
    when(keys.masterKeyPair).thenReturn(identity);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reputationServiceProvider.overrideWithValue(service),
        reputationNodeSupportProvider.overrideWith(
          (ref) async => (issuer: nodeIssuer, importIssuers: importIssuers),
        ),
        settingsProvider.overrideWith((ref) => _Settings(fullPrivacy)),
        keyManagerProvider.overrideWithValue(keys),
      ],
      child: const MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: ReputationScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('export asks to confirm the identity before binding it',
      (tester) async {
    final service = await pump(tester, nodeIssuer: issuer);
    await tester.tap(find.text('Export my reputation').last);
    await tester.pumpAndSettle();
    expect(
        find.textContaining(NostrUtils.encodePublicKeyToNpub(identity.public)),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.exports, 0);

    await tester.tap(find.text('Export my reputation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(service.exports, 1);
    expect(find.textContaining('Your reputation is ready'), findsOneWidget);
  });

  testWidgets('a node that does not export says so', (tester) async {
    await pump(tester);
    expect(
        find.text('This Mostro does not export reputation.'), findsOneWidget);
    expect(find.text('Export my reputation'), findsOneWidget,
        reason: 'only the title');
  });

  testWidgets('shows the node refusal of an export', (tester) async {
    final service = await pump(tester, nodeIssuer: issuer);
    service.refuseWith = 'not_eligible_for_reputation_export';
    await tester.tap(find.text('Export my reputation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 10 completed trades'), findsOneWidget);
  });

  testWidgets('signs a rebind authorisation for a valid npub only',
      (tester) async {
    await pump(tester, nodeIssuer: issuer);
    await tester.enterText(find.byType(TextField).last, 'not-an-npub');
    await tester.tap(find.text('Sign authorization'));
    await tester.pumpAndSettle();
    expect(find.text('That is not a valid npub.'), findsOneWidget);

    final newIdentity =
        NostrKeyPairs(private: secrets['new-identity'] as String).public;
    await tester.enterText(find.byType(TextField).last,
        NostrUtils.encodePublicKeyToNpub(newIdentity));
    await tester.tap(find.text('Sign authorization'));
    await tester.pumpAndSettle();
    expect(find.text('rebind:$issuer:$newIdentity'), findsOneWidget);
  });

  testWidgets('full privacy mode disables both directions', (tester) async {
    await pump(tester, nodeIssuer: issuer, fullPrivacy: true);
    expect(find.textContaining('Turn off full privacy mode'), findsOneWidget);
    final export = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Export my reputation'));
    expect(export.onPressed, isNull);
  });

  testWidgets('exports with a pasted rebind authorisation', (tester) async {
    // Arrange: on the new identity, the user pastes the authorisation the
    // identity the reputation is bound to signed for it.
    final service = await pump(tester, nodeIssuer: issuer);
    const authorisation = '{"kind":38388,"tags":[["z","reputation-rebind"]]}';

    // Act: one export without it, one with it.
    await tester.tap(find.text('Export my reputation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '  $authorisation\n');
    await tester.tap(find.text('Export my reputation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    // Assert
    expect(service.rebinds, [null, authorisation]);
  });

  testWidgets('a node that does not import says so', (tester) async {
    // Arrange / Act
    await pump(tester, nodeIssuer: issuer, importIssuers: null);

    // Assert: no way into a flow that can only end in node_does_not_import.
    expect(
        find.text('This Mostro does not import reputation.'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Import reputation'), findsNothing);
  });
}
