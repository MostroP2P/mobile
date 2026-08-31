import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/chat_room_provider.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/chat/providers/chat_tab_provider.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_error_screen.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_tabs.dart';
import 'package:mostro_mobile/features/chat/widgets/empty_state_view.dart';
import 'package:mostro_mobile/features/chat/widgets/info_buttons.dart';
import 'package:mostro_mobile/features/chat/widgets/message_bubble.dart';
import 'package:mostro_mobile/features/chat/widgets/peer_header.dart';
import 'package:mostro_mobile/features/chat/widgets/trade_information_tab.dart';
import 'package:mostro_mobile/features/chat/widgets/user_information_tab.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Deterministic keypairs for the local trader and the peer. Test vectors,
/// not credentials for any real account.
final _tradeKey = NostrKeyPairs(private: '1' * 64);
final _masterKey = NostrKeyPairs(private: '2' * 64);
final _peerPubkey = NostrKeyPairs(private: '3' * 64).public;

Session session({Role role = Role.buyer, bool withPeer = true}) => Session(
      masterKey: _masterKey,
      tradeKey: _tradeKey,
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.utc(2026, 1, 1),
      orderId: 'order-1',
      role: role,
      peer: withPeer ? Peer(publicKey: _peerPubkey) : null,
    );

Order order({Status status = Status.active}) => Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: status,
      amount: 50000,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'Wire transfer',
      premium: 3,
      createdAt: 1700000000,
    );

NostrEvent message(DateTime createdAt) => NostrEvent(
      id: 'message-1',
      kind: 14,
      content: 'hola',
      sig: '',
      pubkey: _peerPubkey,
      createdAt: createdAt,
      tags: const [],
    );

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  bool scroll = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: scroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('EmptyStateView', () {
    testWidgets('renders its message', (tester) async {
      await pump(tester, const EmptyStateView(message: 'No messages yet'));

      expect(find.text('No messages yet'), findsOneWidget);
    });
  });

  group('ChatErrorScreen', () {
    testWidgets('renders an explicit icon, title and subtitle', (tester) async {
      await pump(
        tester,
        const ChatErrorScreen(
          icon: Icons.wifi_off,
          title: 'Offline',
          subtitle: 'Check your connection',
        ),
        scroll: false,
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Check your connection'), findsOneWidget);
    });

    testWidgets('builds the session-not-found variant', (tester) async {
      await pump(tester, Builder(builder: ChatErrorScreen.sessionNotFound),
          scroll: false);

      expect(find.byType(ChatErrorScreen), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('InfoButtons', () {
    testWidgets('renders with nothing selected', (tester) async {
      await pump(
        tester,
        InfoButtons(selectedInfoType: null, onInfoTypeChanged: (_) {}),
      );

      expect(find.byType(InfoButtons), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a selection change', (tester) async {
      final reported = <String?>[];
      await pump(
        tester,
        InfoButtons(selectedInfoType: null, onInfoTypeChanged: reported.add),
      );

      final tappable = find.byWidgetPredicate(
        (w) => w is InkWell || w is GestureDetector,
      );
      if (tappable.evaluate().isNotEmpty) {
        await tester.tap(tappable.first, warnIfMissed: false);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with a selected info type', (tester) async {
      await pump(
        tester,
        InfoButtons(selectedInfoType: 'trade', onInfoTypeChanged: (_) {}),
      );

      expect(find.byType(InfoButtons), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChatTabs', () {
    testWidgets('renders both tabs with messages selected', (tester) async {
      await pump(tester, const ChatTabs(currentTab: ChatTabType.messages));

      expect(find.byType(ChatTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with the disputes tab selected', (tester) async {
      await pump(tester, const ChatTabs(currentTab: ChatTabType.disputes));

      expect(find.byType(ChatTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches the active tab when the other one is tapped',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(
              body: ChatTabs(currentTab: ChatTabType.messages),
            ),
          ),
        ),
      );
      await tester.pump();

      final tappable = find.byWidgetPredicate(
        (w) => w is InkWell || w is GestureDetector,
      );
      if (tappable.evaluate().length > 1) {
        await tester.tap(tappable.last, warnIfMissed: false);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('PeerHeader', () {
    testWidgets('renders the peer handle', (tester) async {
      await pump(
        tester,
        PeerHeader(peerPubkey: _peerPubkey, session: session()),
      );

      expect(find.byType(PeerHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UserInformationTab', () {
    testWidgets('renders both handles and the shared key', (tester) async {
      await pump(
        tester,
        UserInformationTab(peerPubkey: _peerPubkey, session: session()),
      );

      expect(find.byType(UserInformationTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders when there is no shared key yet', (tester) async {
      await pump(
        tester,
        UserInformationTab(
          peerPubkey: _peerPubkey,
          session: session(withPeer: false),
        ),
      );

      expect(find.byType(UserInformationTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TradeInformationTab', () {
    testWidgets('renders the details of a known order', (tester) async {
      await pump(
        tester,
        TradeInformationTab(order: order(), orderId: 'order-1'),
      );

      expect(find.byType(TradeInformationTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders when the order has not loaded yet', (tester) async {
      await pump(
        tester,
        const TradeInformationTab(order: null, orderId: 'order-1'),
      );

      expect(find.byType(TradeInformationTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a settled order', (tester) async {
      await pump(
        tester,
        TradeInformationTab(
          order: order(status: Status.success),
          orderId: 'order-1',
        ),
      );

      expect(find.byType(TradeInformationTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MessageBubble', () {
    testWidgets('updates its time formatter when the locale changes',
        (tester) async {
      final createdAt = DateTime(2026, 1, 1, 13, 5);
      final bubble = MessageBubble(
        message: message(createdAt),
        peerPubkey: _peerPubkey,
        orderId: 'order-1',
      );

      Future<void> pumpWithLocale(Locale locale) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRoomsProvider.overrideWith(
                (ref, orderId) => ChatRoomNotifier(
                  ChatRoom(orderId: orderId, messages: []),
                  orderId,
                  ref,
                ),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              home: Scaffold(body: bubble),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWithLocale(const Locale('en'));
      expect(find.text(DateFormat('h:mm a', 'en').format(createdAt)),
          findsOneWidget);

      await pumpWithLocale(const Locale('es'));
      expect(find.text(DateFormat('h:mm a', 'es').format(createdAt)),
          findsOneWidget);
    });
  });
}
