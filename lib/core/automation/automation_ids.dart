/// Stable semantic identifiers for UI automation (Mortsom automation
/// contract). Every actionable control and business-critical state carries
/// one of these through `Semantics(identifier: ...)`; on Android they surface
/// as the accessibility `resource-id`, so black-box drivers can locate them
/// without depending on localized text or widget hierarchy.
///
/// Rules (see `docs/automation-contract.md`):
///  * identifiers are namespaced `<area>.<screen-or-flow>.<control>`;
///  * an identifier is a product contract: renaming or removing one requires
///    coordinated review with the automation owners;
///  * dynamic identifiers use the `withKey` helpers so their shape is
///    documented in one place.
class AutomationIds {
  AutomationIds._();

  // Environment
  static const String envMarker = 'env.marker';

  // App bar / navigation
  static const String appBarDrawer = 'appbar.drawer';
  static const String appBarBack = 'appbar.back';
  static const String navOrderBook = 'nav.order_book';
  static const String navTrades = 'nav.trades';
  static const String navChat = 'nav.chat';
  static const String drawerAccount = 'drawer.account';
  static const String drawerSettings = 'drawer.settings';
  static const String drawerAbout = 'drawer.about';

  // Onboarding
  static const String onboardingBack = 'onboarding.walkthrough.back';
  static const String onboardingSkip = 'onboarding.walkthrough.skip';
  static const String onboardingNext = 'onboarding.walkthrough.next';
  static const String onboardingDone = 'onboarding.walkthrough.done';
  static const String communityNoticeAccept =
      'onboarding.community.notice.accept';
  static const String communityCustomNode = 'onboarding.community.custom_node';
  static const String communityDone = 'onboarding.community.done';
  static const String communitySkip = 'onboarding.community.skip';
  static String communityCard(String pubkey) =>
      'onboarding.community.card.$pubkey';

  // Key management
  static const String keysGenerate = 'keys.generate';
  static const String keysGenerateConfirm = 'keys.generate.confirm';
  static const String keysGenerateCancel = 'keys.generate.cancel';
  static const String keysImport = 'keys.import';
  static const String keysImportMnemonic = 'keys.import.mnemonic';
  static const String keysImportConfirm = 'keys.import.confirm';
  static const String keysImportCancel = 'keys.import.cancel';
  static const String keysSeedReveal = 'keys.seed.reveal';
  static const String keysSeedText = 'keys.seed.text';
  static const String keysPublicKey = 'keys.public_key';

  // Settings
  static const String settingsMostroNode = 'settings.mostro_node';
  static const String settingsMostroNodePubkey = 'settings.mostro_node.pubkey';
  static const String settingsWallet = 'settings.wallet';
  static const String settingsRelaysAdd = 'settings.relays.add';
  static const String settingsRelaysAddUrl = 'settings.relays.add.url';
  static const String settingsRelaysAddConfirm = 'settings.relays.add.confirm';
  static const String settingsRelaysAddCancel = 'settings.relays.add.cancel';
  static String settingsRelayItem(String url) =>
      'settings.relays.item.${_normalizeRelayUrl(url)}';
  static String settingsRelayDelete(String url) =>
      'settings.relays.item.${_normalizeRelayUrl(url)}.delete';

  /// A relay URL reaches the UI with and without a trailing slash and both
  /// name the same relay, so the identifier normalizes it the way the relay
  /// list itself does. Without a URL key every delete control would share one
  /// identifier and automation could not pick a relay to remove.
  static String _normalizeRelayUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  // Mostro node selector
  static const String nodeAddCustom = 'node.add_custom';
  static const String nodeCustomPubkey = 'node.custom.pubkey';
  static const String nodeCustomName = 'node.custom.name';
  static const String nodeCustomConfirm = 'node.custom.confirm';
  static const String nodeCustomCancel = 'node.custom.cancel';
  static String nodeItem(String pubkey) => 'node.item.$pubkey';

  // Wallet / NWC
  static const String walletNwcUri = 'wallet.nwc.uri';
  static const String walletNwcConnect = 'wallet.nwc.connect';
  static const String walletConnection = 'wallet.connection';
  static const String walletSettingsConnect = 'wallet.settings.connect';
  static const String walletSettingsDisconnect = 'wallet.settings.disconnect';

  // Order book and creation
  static const String orderBookTabBuy = 'order.book.tab.buy';
  static const String orderBookTabSell = 'order.book.tab.sell';
  static const String orderAddFab = 'order.add.fab';
  static const String orderAddBuy = 'order.add.buy';
  static const String orderAddSell = 'order.add.sell';
  static String orderBookItem(String orderId) => 'order.book.item.$orderId';
  static const String orderCreateCurrency = 'order.create.currency';
  static String orderCreateCurrencyOption(String code) =>
      'order.create.currency.$code';
  static const String orderCreateFiatAmount = 'order.create.fiat_amount';
  static const String orderCreateFiatAmountMax = 'order.create.fiat_amount_max';
  static const String orderCreatePaymentMethod = 'order.create.payment_method';
  static const String orderCreatePriceType = 'order.create.price_type';
  static const String orderCreateSatsAmount = 'order.create.sats_amount';
  static const String orderCreateSubmit = 'order.create.submit';
  static const String orderCreateCancel = 'order.create.cancel';
  static const String orderConfirmHome = 'order.confirm.home';

  // Take order and trade detail
  static const String orderTakeConfirm = 'order.take.confirm';
  static const String orderTakeClose = 'order.take.close';
  static const String orderTakeAmount = 'order.take.amount';
  static const String orderTakeAmountConfirm = 'order.take.amount.confirm';
  static const String orderId = 'order.id';
  static const String orderStatus = 'order.status';
  static String tradesItem(String orderId) => 'trades.item.$orderId';
  static const String tradesItemStatus = 'trades.item.status';
  static String tradeAction(String action) => 'trade.$action';
  static const String tradePayInvoice = 'trade.payInvoice';
  static const String tradeAddInvoice = 'trade.addInvoice';
  static const String tradeTakeSell = 'trade.takeSell';
  static const String tradeTakeBuy = 'trade.takeBuy';
  static const String tradeFiatSent = 'trade.fiatSent';
  static const String tradeRelease = 'trade.release';
  static const String tradeReleaseConfirm = 'trade.release.confirm';
  static const String tradeCancel = 'trade.cancel';
  static const String tradeCancelConfirm = 'trade.cancel.confirm';
  static const String tradeDispute = 'trade.dispute';
  static const String tradeDisputeConfirm = 'trade.dispute.confirm';

  // Invoices and payments
  static const String invoiceText = 'invoice.text';
  static const String invoiceSubmit = 'invoice.submit';
  static const String invoiceCancel = 'invoice.cancel';
  static const String invoiceNwcGenerate = 'invoice.nwc.generate';
  static const String invoiceNwcConfirm = 'invoice.nwc.confirm';
  static const String invoiceNwcText = 'invoice.nwc.text';
  static const String payInvoiceText = 'pay.invoice.text';
  static const String payNwc = 'pay.nwc';
  static const String payCancel = 'pay.cancel';
}
