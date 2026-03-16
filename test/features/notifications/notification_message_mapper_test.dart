import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/generated/l10n.dart';

void main() {
  group('NotificationMessageMapper', () {
    testWidgets('uses timeout-specific cancellation copy when reason is counterparty-timeout', (tester) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final message = NotificationMessageMapper.getLocalizedMessage(
        context,
        mostro.Action.canceled,
        values: const {'reason': 'counterparty-timeout'},
      );

      expect(
        message,
        'The counterparty did not respond in time. The order has been canceled.',
      );
    });

    testWidgets('keeps generic cancellation copy for other cancellation reasons', (tester) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final message = NotificationMessageMapper.getLocalizedMessage(
        context,
        mostro.Action.canceled,
        values: const {'reason': 'user-canceled'},
      );

      expect(message, 'The order has been canceled');
    });
  });
}
