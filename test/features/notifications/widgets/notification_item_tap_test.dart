import 'package:flutter/material.dart' hide Action;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_content.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_item.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';

/// Minimal repository fake: the tap handler only calls markAsRead.
class _FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> getAllNotifications() async => [];
  @override
  Future<void> addNotification(NotificationModel notification) async {}
  @override
  Future<void> markAsRead(String notificationId) async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> deleteNotification(String notificationId) async {}
  @override
  Future<void> deleteByOrderId(String orderId) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Stream<List<NotificationModel>> watchNotifications() => const Stream.empty();
  @override
  Future<List<NotificationModel>> getUnreadNotifications() async => [];
  @override
  Future<bool> notificationExists(String notificationId) async => false;
}

NotificationModel _bondSlashed() => NotificationModel(
      id: 'n-bond',
      type: NotificationType.cancellation,
      action: Action.bondSlashed,
      title: 'notification_bond_slashed_title',
      message: 'notification_bond_slashed_message',
      timestamp: DateTime.now(),
      orderId: 'order-1',
      data: const {
        'amount': 1000,
        'order_id': 'order-1',
        'fiat_code': 'CUP',
        'fiat_amount': 333,
        'payment_method': 'Saldo móvil',
      },
    );

/// A no-op action that shares the bond-slashed switch group and must NOT
/// open the dialog (regression guard against switch fall-through).
NotificationModel _cantDo() => NotificationModel(
      id: 'n-cantdo',
      type: NotificationType.system,
      action: Action.cantDo,
      title: 'notification_cant_do_title',
      message: 'notification_cant_do_message',
      timestamp: DateTime.now(),
      orderId: 'order-2',
      data: const {},
    );

Widget _wrap(NotificationModel notification) {
  return ProviderScope(
    overrides: [
      notificationsRepositoryProvider
          .overrideWithValue(_FakeNotificationsRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: Scaffold(body: NotificationItem(notification: notification)),
    ),
  );
}

void main() {
  group('NotificationItem tap dispatch', () {
    testWidgets('bond-slashed opens the forfeiture dialog', (tester) async {
      await tester.pumpWidget(_wrap(_bondSlashed()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationContent), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a no-op action in the same group does NOT open the dialog',
        (tester) async {
      await tester.pumpWidget(_wrap(_cantDo()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationContent), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
