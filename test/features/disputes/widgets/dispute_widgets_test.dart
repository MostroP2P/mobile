import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_description.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_header.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_icon.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_list_item.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_order_id.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_badge.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_content.dart';
import 'package:mostro_mobile/generated/l10n.dart';

DisputeData disputeData({
  String status = 'initiated',
  DisputeDescriptionKey descriptionKey = DisputeDescriptionKey.initiatedByUser,
  String? counterparty,
  String? orderId = 'order-1',
  bool? isCreator = true,
  UserRole userRole = UserRole.buyer,
  String? action,
}) =>
    DisputeData(
      disputeId: 'dispute-1',
      orderId: orderId,
      status: status,
      descriptionKey: descriptionKey,
      counterparty: counterparty,
      isCreator: isCreator,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4),
      userRole: userRole,
      action: action,
    );

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('DisputeIcon', () {
    testWidgets('renders', (tester) async {
      await pump(tester, const DisputeIcon());

      expect(find.byType(DisputeIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeDescription', () {
    testWidgets('renders the description text', (tester) async {
      await pump(
          tester, const DisputeDescription(description: 'Fiat never arrived'));

      expect(find.textContaining('Fiat never arrived', findRichText: true),
          findsWidgets);
    });

    testWidgets('renders an empty description without throwing',
        (tester) async {
      await pump(tester, const DisputeDescription(description: ''));

      expect(find.byType(DisputeDescription), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeOrderId', () {
    testWidgets('renders the order id', (tester) async {
      await pump(tester, const DisputeOrderId(orderId: 'order-abc'));

      expect(
          find.textContaining('order-abc', findRichText: true), findsWidgets);
    });
  });

  group('DisputeStatusBadge', () {
    testWidgets('renders a badge for every known status', (tester) async {
      const statuses = [
        'initiated',
        'in-progress',
        'in_progress',
        'resolved',
        'seller-refunded',
        'seller_refunded',
        'closed',
        'released',
        'settled-by-admin',
      ];

      for (final status in statuses) {
        await pump(tester, DisputeStatusBadge(status: status));

        expect(find.byType(DisputeStatusBadge), findsOneWidget,
            reason: 'status $status should render');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders an unrecognised status without throwing',
        (tester) async {
      await pump(tester, const DisputeStatusBadge(status: 'martian'));

      expect(find.byType(DisputeStatusBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an empty status without throwing', (tester) async {
      await pump(tester, const DisputeStatusBadge(status: ''));

      expect(find.byType(DisputeStatusBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeHeader', () {
    testWidgets('renders the dispute id and status', (tester) async {
      await pump(tester, DisputeHeader(dispute: disputeData()));

      expect(find.byType(DisputeHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeInfoCard', () {
    testWidgets('renders with a known counterparty', (tester) async {
      await pump(
        tester,
        DisputeInfoCard(dispute: disputeData(counterparty: 'a' * 64)),
      );

      expect(find.byType(DisputeInfoCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders when the counterparty is unknown', (tester) async {
      await pump(tester, DisputeInfoCard(dispute: disputeData()));

      expect(find.byType(DisputeInfoCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without an order id', (tester) async {
      await pump(tester, DisputeInfoCard(dispute: disputeData(orderId: null)));

      expect(find.byType(DisputeInfoCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeStatusContent', () {
    testWidgets('renders each dispute lifecycle status', (tester) async {
      const cases = <(String, DisputeDescriptionKey)>[
        ('initiated', DisputeDescriptionKey.initiatedByUser),
        ('initiated', DisputeDescriptionKey.initiatedByPeer),
        ('initiated', DisputeDescriptionKey.initiatedPendingAdmin),
        ('in-progress', DisputeDescriptionKey.inProgress),
        ('resolved', DisputeDescriptionKey.resolved),
        ('seller-refunded', DisputeDescriptionKey.sellerRefunded),
        ('closed', DisputeDescriptionKey.unknown),
      ];

      for (final (status, key) in cases) {
        await pump(
          tester,
          DisputeStatusContent(
            dispute: disputeData(
              status: status,
              descriptionKey: key,
              counterparty: 'b' * 64,
            ),
          ),
        );

        expect(find.byType(DisputeStatusContent), findsOneWidget,
            reason: '$status/$key should render');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders for a seller with an unknown counterparty',
        (tester) async {
      await pump(
        tester,
        DisputeStatusContent(
          dispute: disputeData(userRole: UserRole.seller, isCreator: false),
        ),
      );

      expect(find.byType(DisputeStatusContent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeListItem', () {
    testWidgets('renders and reports taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DisputeListItem(dispute: disputeData(), onTap: () => taps++),
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(DisputeListItem),
              matching: find.byType(GestureDetector),
            )
            .first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a resolved dispute', (tester) async {
      await pump(
        tester,
        DisputeListItem(
          dispute: disputeData(
            status: 'resolved',
            descriptionKey: DisputeDescriptionKey.resolved,
            action: 'admin-settled',
          ),
          onTap: () {},
        ),
      );

      expect(find.byType(DisputeListItem), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
