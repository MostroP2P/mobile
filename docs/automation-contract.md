# Automation contract

This document is the product contract between the mobile app and black-box
UI automation (Mortsom, `../mortsom`). It covers stable semantic identifiers,
the test-environment build, and the rules for changing either. Everything
here is product code: changes go through normal review, and a change to an
identifier, a visible business state or the test-environment behaviour is a
**contract change** that requires coordinated review with the automation
owners.

## 1. Semantic identifiers

Every actionable control and business-critical state carries a stable
identifier from `lib/core/automation/automation_ids.dart`, attached with the
`.withAutomationId()` extension (`lib/core/automation/automation_id.dart`).

**Declaring an identifier is not attaching it.** A shell identifier such as
`appbar.back` belongs to every screen that offers that control, and a screen
that builds its own `AppBar` owns the job of naming its leading button. The
contract test checks that identifiers are declared, unique and namespaced --
it cannot see which screens attached them -- so a screen that forgets one
leaves the suite green and the driver with no way out. `settings` shipped
that way: the only exit from the screen was invisible to accessibility.
Flutter exposes it as `Semantics.identifier`, which Android surfaces as the
accessibility `resource-id`; drivers locate it with a UiAutomator
`resourceId("<id>")` selector. Identifiers are namespaced
`<area>.<screen-or-flow>.<control>` and never localized.

The extension applies at the end of the expression rather than wrapping it,
so naming a control neither re-indents its subtree nor adds a level of
nesting to `build()`:

```dart
ElevatedButton(
  onPressed: _submit,
  child: Text(S.of(context)!.confirm),
).withAutomationId(AutomationIds.orderConfirm)
```

It builds the `AutomationId` widget underneath; reach for that widget
directly only where an extension call cannot be expressed.

Two modes exist:

- **merged** (default): the wrapped subtree collapses into one node, so the
  identifier travels with the visible label, the enabled flag and the tap
  action. Use it for buttons, text fields and single-purpose controls.
- **container** (`merge: false`): the identifier names a row or card that
  contains several independent controls; an explicit `label` may describe a
  business state (`connected` / `disconnected`, the wire status of an order).

`test/core/automation/automation_contract_test.dart` fails when an identifier
listed below disappears, is renamed, or stops being namespaced.

| Identifier | Owner | Behavioural contract |
|---|---|---|
| `env.marker` | app shell | Present on every screen only in the test environment; label `TEST ENVIRONMENT · Mortsom`. |
| `appbar.drawer`, `appbar.back` | shell | Open the drawer / go back. |
| `nav.order_book`, `nav.trades`, `nav.chat` | shell | Bottom navigation tabs. |
| `drawer.account`, `drawer.settings`, `drawer.about` | shell | Drawer destinations. |
| `onboarding.walkthrough.{back,skip,next,done}` | onboarding | Walkthrough controls; `done`/`skip` mark first run complete. |
| `onboarding.community.card.<pubkey>` | onboarding | Selects that community/node. |
| `onboarding.community.notice.accept` | onboarding | Accepts the legal notice raised on first launch. |
| `onboarding.community.custom_node` | onboarding | Opens the custom-node dialog. |
| `onboarding.community.done`, `onboarding.community.skip` | onboarding | Confirm selection / skip. |
| `keys.public_key` | account | Read-only npub of the current account (label = npub). |
| `keys.generate`, `keys.generate.confirm`, `keys.generate.cancel` | account | Generate a new identity; confirm or dismiss the dialog. |
| `keys.import`, `keys.import.mnemonic`, `keys.import.confirm`, `keys.import.cancel` | account | Import a mnemonic; the field is a secret input and is never logged. |
| `keys.seed.reveal`, `keys.seed.text` | account | Reveal / display the seed phrase (sensitive; automation never records it). |
| `settings.mostro_node`, `settings.mostro_node.pubkey` | settings | Opens the node selector; read-only pubkey of the selected node. |
| `settings.wallet` | settings | Wallet status card; opens wallet settings. |
| `settings.relays.add`, `settings.relays.add.url`, `settings.relays.add.confirm`, `settings.relays.add.cancel` | relays | Add a relay through the dialog. |
| `settings.relays.item.<url>`, `settings.relays.item.<url>.delete` | relays | Relay row and its delete control. `<url>` is the relay URL with trailing slashes removed, so one relay never carries two identifiers. |
| `node.add_custom`, `node.custom.pubkey`, `node.custom.name`, `node.custom.confirm`, `node.custom.cancel`, `node.item.<pubkey>` | mostro node | Custom node dialog and node rows. |
| `wallet.nwc.uri`, `wallet.nwc.connect` | wallet | NWC URI input (secret) and connect action. |
| `wallet.connection` | wallet | State readout; label is `connected` or `disconnected`. |
| `wallet.settings.connect`, `wallet.settings.disconnect` | wallet | Open the connect screen / disconnect the wallet from wallet settings. |
| `order.book.tab.buy`, `order.book.tab.sell` | order book | Switch the book between buy and sell offers. |
| `order.add.fab`, `order.add.buy`, `order.add.sell` | order book | Open the create-order menu and pick a side. |
| `order.book.item.<orderId>` | order book | Opens the order (take screen or trade detail). |
| `order.create.currency`, `order.create.currency.<CODE>` | create order | Currency picker and its options. |
| `order.create.fiat_amount`, `order.create.fiat_amount_max` | create order | Fiat amount (and range maximum). |
| `order.create.payment_method`, `order.create.price_type`, `order.create.sats_amount` | create order | Payment method, market/fixed toggle, sats amount (fixed price). |
| `order.create.submit`, `order.create.cancel`, `order.confirm.home` | create order | Submit / cancel; back to home from the confirmation screen. |
| `order.take.confirm`, `order.take.close`, `order.take.amount`, `order.take.amount.confirm` | take order | Take the order; range amount dialog. |
| `order.id` | trade | Read-only order id (label = id). |
| `order.status` | trade | Read-only order status; label is the wire status (`pending`, `waiting-payment`, `active`, `fiat-sent`, `success`, `canceled`, ...). On the maker's own pending order the trade detail shows the creator reputation instead of the Mostro message card, so there the status comes from an invisible readout; exactly one node either way. |
| `trades.item.<orderId>`, `trades.item.status` | trades | Trade row; status chip whose label is the wire status. |
| `trade.<action>` (`trade.payInvoice`, `trade.addInvoice`, `trade.fiatSent`, `trade.release`, `trade.takeSell`, `trade.takeBuy`, `trade.rate`, `trade.cancel`, `trade.dispute`, ...) | trade | Trade action buttons named after the protocol action. |
| `trade.release.confirm`, `trade.cancel.confirm`, `trade.dispute.confirm` | trade | Confirmation dialogs. |
| `invoice.text`, `invoice.submit`, `invoice.cancel` | invoice | Buyer invoice entry. |
| `invoice.nwc.generate`, `invoice.nwc.confirm` | invoice | Generate the buyer invoice with the connected wallet and confirm it. |
| `invoice.nwc.text` | invoice | Read-only generated buyer invoice (label = bolt11). |
| `pay.invoice.text` | payment | Read-only invoice being paid (label = bolt11); invisible readout for correlation. |
| `pay.nwc` | payment | Pay the displayed invoice with the connected wallet. |
| `pay.cancel` | payment | Cancel the order from the pay-invoice screen. |

## 2. Test-environment build

The Mortsom build is the same application with a different Dart entry point:

```sh
flutter build apk -t lib/main_mortsom.dart \
  --dart-define=MORTSOM_TEST_ENV=true \
  --dart-define=MOSTRO_PUB_KEY=<daemon pubkey> \
  --dart-define=MORTSOM_RELAYS=ws://10.0.2.2:7000
```

`lib/core/test_environment.dart` enables the test environment only when
**both** the entry point armed it and `MORTSOM_TEST_ENV=true` was compiled
in. `lib/main.dart` never arms it, and the release pipeline never passes the
define, so a release build cannot enter the test environment by accident.
When enabled:

- the local relay seed list (`MORTSOM_RELAYS`) becomes the user relays on the
  first launch of a fresh install, before any subscription starts;
- relay discovery never falls back to the public bootstrap relays
  (`Config.bootstrapRelays`): `Config.discoveryRelays` resolves to the seed
  list instead, so a disconnected local relay produces a test failure, not
  public-network traffic. A build that arms the test environment without
  `MORTSOM_RELAYS` fails at startup rather than starting with no relay;
- plain `ws://` relays on local hosts (`localhost` or a private IPv4 address:
  loopback, 10/8, 172.16/12, 192.168/16, optional port) are accepted by the
  add-relay validation (`ws://` is never accepted towards a public host, and a
  public IPv4 address is never a local host). Non-release builds (debug and profile, see
  `Config.allowInsecureRelays`) accept them too, independently of the test
  environment; a release build accepts them only inside the test environment
  (armed entry point plus the define), never on its own;
- a red `TEST ENVIRONMENT · Mortsom` banner (`env.marker`) is shown on every
  screen.

The banner copy is deliberately not localized: it is test-only tooling and
follows Mortsom's English-only policy.

Only non-secret values travel through Dart defines (daemon pubkey, relay
endpoints). Mnemonics and NWC URIs are entered through the UI by the
automation, never compiled in and never logged.

## 3. Changing the contract

1. Update `AutomationIds`, the call site, and this table, in one change.
2. Keep `flutter test test/core/automation` green; add the identifier to the
   contract test list.
3. Notify the automation owners; Mortsom's adapter contract tests pin the
   same identifiers.
