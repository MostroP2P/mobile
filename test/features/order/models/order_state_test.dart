import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/cant_do.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/payment_failed.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

const _buyerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _sellerPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _adminPubkey =
    '3333333333333333333333333333333333333333333333333333333333333333';

Order order({
  Status status = Status.pending,
  String? buyerTradePubkey,
  String? sellerTradePubkey,
  OrderType kind = OrderType.sell,
}) =>
    Order(
      id: 'order-1',
      kind: kind,
      status: status,
      amount: 50000,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'Wire transfer',
      buyerTradePubkey: buyerTradePubkey,
      sellerTradePubkey: sellerTradePubkey,
    );

MostroMessage<T> message<T extends Payload>(
  Action action, {
  T? payload,
  int? timestamp,
}) =>
    MostroMessage<T>(
      action: action,
      id: 'order-1',
      payload: payload,
      timestamp: timestamp,
    );

OrderState baseState({
  Status status = Status.pending,
  Action action = Action.newOrder,
  bool fiatWasSent = false,
}) =>
    OrderState(
      status: status,
      action: action,
      order: order(status: status),
      fiatWasSent: fiatWasSent,
    );

void main() {
  group('OrderState.fromMostroMessage', () {
    test('takes the status from the order payload', () {
      final state = OrderState.fromMostroMessage(
        message<Order>(Action.newOrder, payload: order(status: Status.active)),
      );

      expect(state.status, Status.active);
      expect(state.action, Action.newOrder);
      expect(state.order?.id, 'order-1');
      expect(state.fiatWasSent, isFalse);
    });

    test('falls back to pending when the message carries no order', () {
      final state = OrderState.fromMostroMessage(message(Action.newOrder));

      expect(state.status, Status.pending);
      expect(state.order, isNull);
      expect(state.paymentRequest, isNull);
      expect(state.cantDo, isNull);
      expect(state.dispute, isNull);
      expect(state.peer, isNull);
      expect(state.paymentFailed, isNull);
    });
  });

  group('OrderState value semantics', () {
    test('two states sharing the same order instance are equal', () {
      final shared = order();
      OrderState build() => OrderState(
            status: Status.pending,
            action: Action.newOrder,
            order: shared,
          );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), equals(build()));
    });

    test('two orderless states built from the same data are equal', () {
      OrderState build() => OrderState(
            status: Status.pending,
            action: Action.newOrder,
            order: null,
          );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    // `Order` now declares value equality, so two structurally identical
    // orders make the surrounding states compare equal — replayed messages
    // no longer look like state changes to watchers.
    test('states holding equal-but-distinct orders compare equal', () {
      expect(baseState(), baseState());
    });

    test('states differing in any field are not equal', () {
      expect(baseState(), isNot(baseState(status: Status.active)));
      expect(baseState(), isNot(baseState(action: Action.cancel)));
      expect(baseState(), isNot(baseState(fiatWasSent: true)));
      expect(baseState(), isNot(equals('not an order state')));
    });

    test('renders every field in toString', () {
      final rendered = baseState().toString();

      expect(rendered, contains('status: pending'));
      expect(rendered, contains('action: new-order'));
      expect(rendered, contains('fiatWasSent: false'));
    });

    test('copyWith overrides only what is given', () {
      final updated = baseState().copyWith(
        status: Status.active,
        fiatWasSent: true,
      );

      expect(updated.status, Status.active);
      expect(updated.fiatWasSent, isTrue);
      expect(updated.action, Action.newOrder);
      expect(updated.order?.id, 'order-1');
    });

    test('copyWith can set every optional payload', () {
      final updated = baseState().copyWith(
        cantDo: CantDo(cantDoReason: CantDoReason.notFound),
        peer: Peer(publicKey: _buyerPubkey),
        paymentFailed:
            PaymentFailed(paymentAttempts: 1, paymentRetriesInterval: 10),
      );

      expect(updated.cantDo?.cantDoReason, CantDoReason.notFound);
      expect(updated.peer?.publicKey, _buyerPubkey);
      expect(updated.paymentFailed?.paymentAttempts, 1);
    });
  });

  group('OrderState peerReputation', () {
    const reputation = UserInfo(rating: 4.375, reviews: 4, operatingDays: 64);

    test('updateWith stores the snapshot from a reputation-only Peer', () {
      final state = baseState().updateWith(
        message<Peer>(
          Action.payInvoice,
          payload: Peer(publicKey: '', reputation: reputation),
        ),
      );

      expect(state.peerReputation, reputation);
      // An empty pubkey must never become the tracked counterpart
      expect(state.peer, isNull);
    });

    test('is preserved across later messages without reputation', () {
      var state = baseState().updateWith(
        message<Peer>(
          Action.addInvoice,
          payload: Peer(publicKey: '', reputation: reputation),
        ),
      );

      // fiat-sent-ok shape: real pubkey, reputation absent
      state = state.updateWith(
        message<Peer>(
          Action.fiatSentOk,
          payload: Peer(publicKey: _buyerPubkey),
        ),
      );
      expect(state.peerReputation, reputation);
      expect(state.peer?.publicKey, _buyerPubkey);

      state = state.updateWith(message(Action.rate));
      expect(state.peerReputation, reputation);
    });

    test('the notice never moves the order it rides on', () {
      final state = baseState(
        status: Status.waitingTakerBond,
        action: Action.payBondInvoice,
      ).updateWith(
        message<Peer>(
          Action.addInvoice,
          payload: Peer(publicKey: '', reputation: reputation),
        ),
      );

      // addInvoice would normally map to waiting-buyer-invoice
      expect(state.status, Status.waitingTakerBond);
      expect(state.action, Action.payBondInvoice);
      expect(state.peerReputation, reputation);
    });

    test('a late notice cannot roll back an order that already advanced', () {
      var state = baseState()
          .updateWith(
            message<Peer>(
              Action.payInvoice,
              payload: Peer(publicKey: '', reputation: reputation),
            ),
          )
          .updateWith(
            message<Order>(
              Action.fiatSentOk,
              payload: order(
                status: Status.fiatSent,
                buyerTradePubkey: _buyerPubkey,
              ),
            ),
          );
      expect(state.status, Status.fiatSent);

      // Redelivered by a slow relay long after the trade moved on
      final afterLateNotice = state.updateWith(
        message<Peer>(
          Action.payInvoice,
          payload: Peer(publicKey: '', reputation: reputation),
        ),
      );

      expect(afterLateNotice.status, Status.fiatSent);
      expect(afterLateNotice.action, Action.fiatSentOk);
      expect(afterLateNotice.order, state.order);
      expect(afterLateNotice.peer?.publicKey, _buyerPubkey);
      expect(afterLateNotice.fiatWasSent, isTrue);
      expect(afterLateNotice.peerReputation, reputation);
    });

    test('a republish after the taker times out drops the snapshot', () {
      var state = baseState()
          .updateWith(
            message<Peer>(
              Action.payInvoice,
              payload: Peer(publicKey: '', reputation: reputation),
            ),
          )
          .updateWith(
            message<Order>(
              Action.waitingBuyerInvoice,
              payload: order(status: Status.waitingBuyerInvoice),
            ),
          );
      expect(state.peerReputation, reputation);

      // Mostro returns the maker's order to the book: there is no taker now
      state = state.updateWith(
        message<Order>(Action.newOrder, payload: order(status: Status.pending)),
      );

      expect(state.status, Status.pending);
      expect(state.peerReputation, isNull);
    });

    test('the next taker snapshot replaces the one that was dropped', () {
      const nextTaker = UserInfo(rating: 2.0, reviews: 1, operatingDays: 3);

      var state = baseState()
          .updateWith(
            message<Peer>(
              Action.payInvoice,
              payload: Peer(publicKey: '', reputation: reputation),
            ),
          )
          .updateWith(
            message<Order>(
              Action.waitingBuyerInvoice,
              payload: order(status: Status.waitingBuyerInvoice),
            ),
          )
          .updateWith(
            message<Order>(
              Action.newOrder,
              payload: order(status: Status.pending),
            ),
          );
      expect(state.peerReputation, isNull);

      state = state.updateWith(
        message<Peer>(
          Action.payInvoice,
          payload: Peer(publicKey: '', reputation: nextTaker),
        ),
      );

      expect(state.peerReputation, nextTaker);
    });

    test('copyWith clears the snapshot only when asked to', () {
      final state = baseState().copyWith(peerReputation: reputation);

      // A bare null preserves, like every other copyWith field
      expect(state.copyWith(peerReputation: null).peerReputation, reputation);
      expect(state.copyWith(clearPeerReputation: true).peerReputation, isNull);
    });

    test('fromMostroMessage picks the snapshot up without setting a peer', () {
      final state = OrderState.fromMostroMessage(
        message<Peer>(
          Action.addInvoice,
          payload: Peer(publicKey: '', reputation: reputation),
        ),
      );

      expect(state.peerReputation, reputation);
      expect(state.peer, isNull);
    });
  });

  group('OrderState.updateWith', () {
    test('a cant-do message only attaches the reason and preserves the rest',
        () {
      final state = baseState(status: Status.active, action: Action.fiatSent);

      final updated = state.updateWith(
        message<CantDo>(
          Action.cantDo,
          payload: CantDo(cantDoReason: CantDoReason.invalidAmount),
        ),
      );

      expect(updated.status, Status.active);
      expect(updated.action, Action.fiatSent);
      expect(updated.cantDo?.cantDoReason, CantDoReason.invalidAmount);
    });

    test('records that fiat was sent and keeps the flag latched', () {
      final afterFiatSent =
          baseState(status: Status.active).updateWith(message(Action.fiatSent));

      expect(afterFiatSent.fiatWasSent, isTrue);

      final afterAnotherMessage =
          afterFiatSent.updateWith(message(Action.sendDm));

      expect(afterAnotherMessage.fiatWasSent, isTrue);
    });

    test('fiatSentOk also latches the fiat flag', () {
      expect(
        baseState(status: Status.active)
            .updateWith(message(Action.fiatSentOk))
            .fiatWasSent,
        isTrue,
      );
    });

    test('remaps a cooperative cancel to the no-fiat variant', () {
      final updated = baseState(status: Status.active)
          .updateWith(message(Action.cooperativeCancelInitiatedByYou));

      expect(updated.action, Action.cooperativeCancelNoFiatByYou);
    });

    test('remaps a peer cooperative cancel to the no-fiat variant', () {
      final updated = baseState(status: Status.active)
          .updateWith(message(Action.cooperativeCancelInitiatedByPeer));

      expect(updated.action, Action.cooperativeCancelNoFiatByPeer);
    });

    test('remaps a cooperative cancel to the fiat-sent variant', () {
      final afterFiat = baseState(status: Status.active, fiatWasSent: true);

      expect(
        afterFiat
            .updateWith(message(Action.cooperativeCancelInitiatedByYou))
            .action,
        Action.cooperativeCancelFiatSentByYou,
      );
      expect(
        afterFiat
            .updateWith(message(Action.cooperativeCancelInitiatedByPeer))
            .action,
        Action.cooperativeCancelFiatSentByPeer,
      );
    });

    test('adopts a peer sent explicitly in the message', () {
      final updated = baseState().updateWith(
        message<Peer>(Action.buyerTookOrder,
            payload: Peer(publicKey: _adminPubkey)),
      );

      expect(updated.peer?.publicKey, _adminPubkey);
    });

    test('derives the peer from the buyer trade pubkey of an order payload',
        () {
      final updated = baseState().updateWith(
        message<Order>(
          Action.buyerTookOrder,
          payload: order(
            status: Status.active,
            buyerTradePubkey: _buyerPubkey,
          ),
        ),
      );

      expect(updated.peer?.publicKey, _buyerPubkey);
    });

    test('falls back to the seller trade pubkey when there is no buyer one',
        () {
      final updated = baseState().updateWith(
        message<Order>(
          Action.waitingSellerToPay,
          payload: order(
            status: Status.waitingPayment,
            sellerTradePubkey: _sellerPubkey,
          ),
        ),
      );

      expect(updated.peer?.publicKey, _sellerPubkey);
    });

    test('preserves the existing peer when the message carries none', () {
      final withPeer =
          baseState().copyWith(peer: Peer(publicKey: _buyerPubkey));

      final updated = withPeer.updateWith(message(Action.sendDm));

      expect(updated.peer?.publicKey, _buyerPubkey);
    });

    test('keeps the current status for informational actions', () {
      const informational = [
        Action.rateUser,
        Action.invoiceUpdated,
        Action.sendDm,
        Action.tradePubkey,
        Action.adminAddSolver,
        Action.addBondInvoice,
      ];

      for (final action in informational) {
        expect(
          baseState(status: Status.active).updateWith(message(action)).status,
          Status.active,
          reason: '$action must not change the status',
        );
      }
    });

    test('keeps the current status for bond acknowledgements', () {
      const bondAcks = [
        Action.bondInvoiceAccepted,
        Action.bondPayoutCompleted,
        Action.bondSlashed,
      ];

      for (final action in bondAcks) {
        expect(
          baseState(status: Status.active).updateWith(message(action)).status,
          Status.active,
          reason: '$action must not change the status',
        );
      }
    });

    test('adopts the status carried by a new-order payload', () {
      final updated = baseState().updateWith(
        message<Order>(Action.newOrder,
            payload: order(status: Status.waitingBuyerInvoice)),
      );

      expect(updated.status, Status.waitingBuyerInvoice);
    });
  });

  group('OrderState.getActions', () {
    test('offers cancel to a seller on a freshly published order', () {
      final state = baseState(status: Status.pending, action: Action.newOrder);

      expect(state.getActions(Role.seller), contains(Action.cancel));
    });

    test('offers pay-invoice to a seller waiting to pay the hold invoice', () {
      final state = baseState(
        status: Status.waitingPayment,
        action: Action.payInvoice,
      );

      expect(state.getActions(Role.seller), contains(Action.payInvoice));
      expect(state.getActions(Role.seller), contains(Action.cancel));
    });

    test('offers pay-bond-invoice while waiting for the taker bond', () {
      final state = baseState(
        status: Status.waitingTakerBond,
        action: Action.payBondInvoice,
      );

      expect(state.getActions(Role.seller), contains(Action.payBondInvoice));
    });

    test('returns an empty list for a status/action pair with no entry', () {
      final state = baseState(status: Status.expired, action: Action.cancel);

      for (final role in Role.values) {
        expect(state.getActions(role), isEmpty);
      }
    });

    test('every advertised action table is reachable and well formed', () {
      OrderState.actions.forEach((role, byStatus) {
        byStatus.forEach((status, byAction) {
          byAction.forEach((action, available) {
            final state = OrderState(
              status: status,
              action: action,
              order: order(status: status),
            );

            expect(
              state.getActions(role),
              available,
              reason: 'actions[$role][$status][$action] must be reachable',
            );
          });
        });
      });
    });

    test('covers both buyer and seller tables', () {
      expect(OrderState.actions.keys, containsAll([Role.buyer, Role.seller]));
      expect(OrderState.actions[Role.seller], isNotEmpty);
      expect(OrderState.actions[Role.buyer], isNotEmpty);
    });
  });
}
