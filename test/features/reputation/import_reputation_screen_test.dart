import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/features/reputation/screens/import_reputation_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';

final Map<String, dynamic> vectors = jsonDecode(
  File('test/fixtures/reputation_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

class _FakeService implements ReputationService {
  final List<String> imported = [];
  String? refuseWith;
  ReputationAttestation? pending;

  @override
  Future<ReputationAttestation?> pendingAttestation() async => pending;

  @override
  Future<ReputationAttestation> importReputation(String json) async {
    if (refuseWith != null) throw ReputationException(refuseWith!);
    imported.add(json);
    return ReputationAttestation.parse(json,
        now: vectors['context']['now'] as int);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final valid = vectors['attestation']['valid']['json'] as String;
  final now = vectors['context']['now'] as int;

  Future<_FakeService> pump(WidgetTester tester) async {
    final service = _FakeService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reputationServiceProvider.overrideWithValue(service),
        reputationClockProvider.overrideWithValue(() => now),
      ],
      child: const MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: ImportReputationScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('shows the figures of a pasted attestation and imports it',
      (tester) async {
    final service = await pump(tester);
    await tester.enterText(find.byType(TextField), 'from the bot:\n$valid');
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('214 ratings received, 4.87 on average'),
        findsOneWidget);

    await tester.ensureVisible(find.text('Import into this Mostro'));
    await tester.tap(find.text('Import into this Mostro'));
    await tester.pumpAndSettle();
    expect(service.imported, [valid]);
    expect(find.text('Your reputation was imported.'), findsOneWidget);
  });

  testWidgets('says why an attestation is refused', (tester) async {
    final service = await pump(tester);
    await tester.enterText(find.byType(TextField), 'nothing useful');
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a valid reputation'), findsOneWidget);

    final expired = jsonEncode((vectors['attestation']['invalid'] as List)
        .firstWhere((c) => c['name'] == 'expired')['event']);
    await tester.enterText(find.byType(TextField), expired);
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('has expired'), findsOneWidget);

    service.refuseWith = 'reputation_already_imported';
    await tester.enterText(find.byType(TextField), valid);
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Import into this Mostro'));
    await tester.tap(find.text('Import into this Mostro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already imported'), findsOneWidget);
  });
}
