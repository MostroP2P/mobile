import 'package:dart_nostr/dart_nostr.dart';
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
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

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

NotificationModel _chatMessage(String orderId) => NotificationModel(
      id: 'n-chat',
      type: NotificationType.system,
      action: Action.chatMessage,
      title: 'notification_chat_message_title',
      message: 'notification_chat_message_message',
      timestamp: DateTime.now(),
      orderId: orderId,
      data: const {},
    );

NotificationModel _solverDm(String orderId) => NotificationModel(
      id: 'n-dm',
      type: NotificationType.system,
      action: Action.sendDm,
      title: 'notification_admin_dm_title',
      message: 'notification_admin_dm_message',
      timestamp: DateTime.now(),
      orderId: orderId,
      data: const {},
    );

Session _session({required String orderId, String? disputeId}) => Session(
      masterKey: NostrKeyPairs(private: NostrUtils.generatePrivateKey()),
      tradeKey: NostrKeyPairs(private: NostrUtils.generatePrivateKey()),
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: orderId,
      disputeId: disputeId,
    );

/// Router harness that records the destination of a tap instead of building
/// the real (provider-heavy) destination screens.
Widget _wrapWithRouter(
  NotificationModel notification, {
  required List<String> visited,
  Session? session,
}) {
  Widget probe(String label, GoRouterState state) {
    visited.add(state.uri.toString());
    return Scaffold(body: Text(label));
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            Scaffold(body: NotificationItem(notification: notification)),
      ),
      GoRoute(
        path: '/chat_room/:orderId',
        builder: (_, state) => probe('chat_room', state),
      ),
      GoRoute(
        path: '/dispute_details/:disputeId',
        builder: (_, state) => probe('dispute_details', state),
      ),
      GoRoute(
        path: '/trade_detail/:orderId',
        builder: (_, state) => probe('trade_detail', state),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      notificationsRepositoryProvider
          .overrideWithValue(_FakeNotificationsRepository()),
      if (session != null)
        sessionProvider(session.orderId!).overrideWith((ref) => session),
    ],
    child: MaterialApp.router(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

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

  group('NotificationItem chat notifications open the chat', () {
    testWidgets('a peer chat message opens the P2P chat room', (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        _wrapWithRouter(_chatMessage('order-chat'), visited: visited),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationContent), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(visited, ['/chat_room/order-chat']);
    });

    testWidgets('a solver DM opens the dispute chat when a dispute is known',
        (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        _wrapWithRouter(
          _solverDm('order-dispute'),
          visited: visited,
          session: _session(
            orderId: 'order-dispute',
            disputeId: 'dispute-42',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationContent), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(visited, ['/dispute_details/dispute-42']);
    });

    testWidgets('a solver DM falls back to the trade detail without a dispute',
        (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        _wrapWithRouter(
          _solverDm('order-nodispute'),
          visited: visited,
          session: _session(orderId: 'order-nodispute'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationContent), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(visited, ['/trade_detail/order-nodispute']);
    });
  });
}
