import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/logs/logs_screen.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import '../../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogsScreen Widget Tests', () {
    late MockLogsService mockLogsService;

    setUp(() {
      mockLogsService = MockLogsService();
      when(mockLogsService.logs).thenReturn([]);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          logsProvider.overrideWith((ref) => mockLogsService),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const LogsScreen(),
        ),
      );
    }

    testWidgets('Initial state shows no logs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Capturamos S.of(context)! de forma segura
      final s = S.of(tester.element(find.byType(LogsScreen)))!;

      expect(find.text(s.noLogsMessage), findsOneWidget);
    });

    testWidgets('Displays logs when added', (tester) async {
      final logLine = '[2025-01-01T12:00:00] INFO Test log';
      when(mockLogsService.logs).thenReturn([logLine]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final s = S.of(tester.element(find.byType(LogsScreen)))!;

      expect(find.textContaining('Test log'), findsOneWidget);
      expect(find.text(s.noLogsMessage), findsNothing);
    });

    testWidgets('Clears logs when delete button pressed', (tester) async {
      final logLine = '[2025-01-01T12:00:00] INFO Log to delete';
      when(mockLogsService.logs).thenReturn([logLine]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final s = S.of(tester.element(find.byType(LogsScreen)))!;

      final deleteButton = find.byTooltip(s.deleteLogsTooltip);
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      verify(mockLogsService.clearLogs()).called(1);
    });

    testWidgets('Exports logs when export button pressed', (tester) async {
      final logLine = '[2025-01-01T12:00:00] INFO Export this log';
      when(mockLogsService.logs).thenReturn([logLine]);

      final fakeFile = File('/tmp/fake_logs.txt');
      when(mockLogsService.getLogFile(clean: true))
          .thenAnswer((_) async => fakeFile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final s = S.of(tester.element(find.byType(LogsScreen)))!;

      final exportButton = find.byTooltip(s.shareLogsTooltip);
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      verify(mockLogsService.getLogFile(clean: true)).called(1);
    });
  });
}
