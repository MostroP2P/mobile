import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/relays/relays_notifier.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/generated/l10n.dart';

import '../../../mocks.mocks.dart';

void main() {
  group('RelaySelector Dialog Integration Tests', () {
    late MockRelaysNotifier mockNotifier;
    
    setUp(() {
      mockNotifier = MockRelaysNotifier();
      when(mockNotifier.state).thenReturn([]);
    });
    
    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          relaysProvider.overrideWith((ref) => mockNotifier),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('it'),
          ],
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => ElevatedButton(
                onPressed: () => RelaySelector.showAddDialog(context, ref),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('should show add relay dialog with proper UI elements', (tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Tap the button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Verify dialog elements are present
      expect(find.text('Add Relay'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('relay.example.com or wss://relay.example.com'), findsOneWidget);
    });

    testWidgets('should show error dialog for invalid input', (tester) async {
      // Mock validation result for invalid input
      when(mockNotifier.addRelayWithSmartValidation(
        'holahola', 
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).thenAnswer((_) async => RelayValidationResult(
        success: false,
        error: 'Invalid domain format. Use format like: relay.example.com',
      ));
      
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter invalid input
      await tester.enterText(find.byType(TextField), 'holahola');
      
      // Tap Add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Wait for loading dialog and error dialog
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Verify error dialog appears
      expect(find.text('Invalid Relay'), findsOneWidget);
      expect(find.text('Invalid domain format. Use format like: relay.example.com'), 
             findsOneWidget);
    });

    testWidgets('should show loading indicator during validation', (tester) async {
      // Mock slow validation
      final completer = Completer<RelayValidationResult>();
      when(mockNotifier.addRelayWithSmartValidation(
        'relay.example.com',
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).thenAnswer((_) => completer.future);
      
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter valid input
      await tester.enterText(find.byType(TextField), 'relay.example.com');
      
      // Tap Add button
      await tester.tap(find.text('Add'));
      await tester.pump();
      
      // Verify loading dialog appears
      expect(find.text('Testing relay...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the validation
      completer.complete(RelayValidationResult(
        success: true,
        normalizedUrl: 'wss://relay.example.com',
        isHealthy: true,
      ));
      
      await tester.pumpAndSettle();
      
      // Loading dialog should be gone
      expect(find.text('Testing relay...'), findsNothing);
    });

    testWidgets('should show success message for valid relay', (tester) async {
      when(mockNotifier.addRelayWithSmartValidation(
        'relay.example.com',
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).thenAnswer((_) async => RelayValidationResult(
        success: true,
        normalizedUrl: 'wss://relay.example.com',
        isHealthy: true,
      ));
      
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter valid input
      await tester.enterText(find.byType(TextField), 'relay.example.com');
      
      // Tap Add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify success message appears
      expect(find.text('Relay added successfully: wss://relay.example.com'), 
             findsOneWidget);
      
      // Dialog should be closed
      expect(find.text('Add Relay'), findsNothing);
    });

    testWidgets('should show error for unreachable relay', (tester) async {
      when(mockNotifier.addRelayWithSmartValidation(
        'unreachable.example.com',
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).thenAnswer((_) async => RelayValidationResult(
        success: false,
        error: 'Not a valid Nostr relay - no response to protocol test',
      ));
      
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter unreachable relay
      await tester.enterText(find.byType(TextField), 'unreachable.example.com');
      
      // Tap Add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify error dialog appears
      expect(find.text('Invalid Relay'), findsOneWidget);
      expect(find.text('Not a valid Nostr relay - no response to protocol test'), 
             findsOneWidget);
    });

    testWidgets('should handle different error types correctly', (tester) async {
      final errorTestCases = [
        {
          'input': 'ws://insecure.example.com',
          'error': 'Only secure websockets (wss://) are allowed',
        },
        {
          'input': 'http://example.com',
          'error': 'HTTP URLs are not supported. Use websocket URLs (wss://)',
        },
        {
          'input': 'wss://existing.relay.com',
          'error': 'This relay is already in your list',
        },
      ];
      
      for (final testCase in errorTestCases) {
        // Setup mock for this test case
        when(mockNotifier.addRelayWithSmartValidation(
          testCase['input']!,
          errorOnlySecure: anyNamed('errorOnlySecure'),
          errorNoHttp: anyNamed('errorNoHttp'),
          errorInvalidDomain: anyNamed('errorInvalidDomain'),
          errorAlreadyExists: anyNamed('errorAlreadyExists'),
          errorNotValid: anyNamed('errorNotValid'),
        )).thenAnswer((_) async => RelayValidationResult(
          success: false,
          error: testCase['error']!,
        ));
        
        await tester.pumpWidget(createTestWidget());
        
        // Show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Enter input
        await tester.enterText(find.byType(TextField), testCase['input']!);
        
        // Tap Add button
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        
        // Verify specific error message
        expect(find.text(testCase['error']!), findsOneWidget,
               reason: 'Error message not found for input: ${testCase['input']}');
        
        // Close error dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        
        // Close add relay dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('should not submit empty input', (tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Leave TextField empty and tap Add
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify no validation was called
      verifyZeroInteractions(mockNotifier);
      
      // Dialog should still be open
      expect(find.text('Add Relay'), findsOneWidget);
    });

    testWidgets('should handle whitespace-only input', (tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter only whitespace
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify no validation was called
      verifyZeroInteractions(mockNotifier);
    });

    testWidgets('should trim input before validation', (tester) async {
      when(mockNotifier.addRelayWithSmartValidation(
        'relay.example.com',
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).thenAnswer((_) async => RelayValidationResult(
        success: true,
        normalizedUrl: 'wss://relay.example.com',
        isHealthy: true,
      ));
      
      await tester.pumpWidget(createTestWidget());
      
      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Enter input with whitespace
      await tester.enterText(find.byType(TextField), '  relay.example.com  ');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify validation was called with trimmed input
      verify(mockNotifier.addRelayWithSmartValidation(
        'relay.example.com',
        errorOnlySecure: anyNamed('errorOnlySecure'),
        errorNoHttp: anyNamed('errorNoHttp'),
        errorInvalidDomain: anyNamed('errorInvalidDomain'),
        errorAlreadyExists: anyNamed('errorAlreadyExists'),
        errorNotValid: anyNamed('errorNotValid'),
      )).called(1);
    });
  });
}