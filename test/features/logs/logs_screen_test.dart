import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/logs/logs_screen.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
// import '../../../test_helpers.dart';
import '../../mocks.mocks.dart';

void main() {
  late MockLogsService mockLogsService;

  setUp(() {
    mockLogsService = MockLogsService();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        logsServiceProvider.overrideWithValue(mockLogsService),
      ],
      child: const MaterialApp(
        home: LogsScreen(),
      ),
    );
  }

  testWidgets('Initial state shows no logs', (WidgetTester tester) async {
    // Arrange: Mock devuelve lista vacía
    when(mockLogsService.logs).thenReturn(UnmodifiableListView<String>([]));

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('No logs yet.'), findsOneWidget);
  });

  testWidgets('Displays logs when added', (WidgetTester tester) async {
    // Arrange: Mock devuelve logs
    when(mockLogsService.logs).thenReturn(
      UnmodifiableListView<String>(['[2025-10-31T00:00:00] Test log']),
    );

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Assert
    expect(find.textContaining('Test log'), findsOneWidget);
  });

  testWidgets('Clears logs when delete button pressed', (WidgetTester tester) async {
    // Arrange
    when(mockLogsService.logs).thenReturn(
      UnmodifiableListView<String>(['[2025-10-31T00:00:00] Test log']),
    );
    when(mockLogsService.clearLogs(clean: anyNamed('clean')))
        .thenAnswer((_) async => {});

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Assert
    verify(mockLogsService.clearLogs(clean: anyNamed('clean'))).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Exports logs when export button pressed', (WidgetTester tester) async {
    // Arrange
    when(mockLogsService.logs).thenReturn(
      UnmodifiableListView<String>(['[2025-10-31T00:00:00] Test log']),
    );
    when(mockLogsService.getLogFile(clean: true))
        .thenAnswer((_) async => null); // Simula que no hay archivo

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap share button
    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();

    // Assert
    verify(mockLogsService.getLogFile(clean: true)).called(1);
  });
}