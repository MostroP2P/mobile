import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/repositories/nwc_storage.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_client.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/services/nwc/nwc_models.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Represents the current state of the NWC wallet connection.
class NwcState extends Equatable {
  final NwcStatus status;
  final String? walletAlias;
  final int? balanceMsats;
  final String? errorMessage;
  final List<String> supportedMethods;

  /// Whether the connection to the wallet relay is healthy.
  final bool connectionHealthy;

  /// Last successful communication timestamp (milliseconds since epoch).
  final int? lastSuccessfulContact;

  const NwcState({
    this.status = NwcStatus.disconnected,
    this.walletAlias,
    this.balanceMsats,
    this.errorMessage,
    this.supportedMethods = const [],
    this.connectionHealthy = false,
    this.lastSuccessfulContact,
  });

  /// Balance converted from millisatoshis to satoshis.
  int? get balanceSats => balanceMsats != null ? (balanceMsats! ~/ 1000) : null;

  NwcState copyWith({
    NwcStatus? status,
    String? walletAlias,
    int? balanceMsats,
    String? errorMessage,
    List<String>? supportedMethods,
    bool? connectionHealthy,
    int? lastSuccessfulContact,
    bool clearError = false,
    bool clearWalletInfo = false,
  }) {
    return NwcState(
      status: status ?? this.status,
      walletAlias: clearWalletInfo ? null : (walletAlias ?? this.walletAlias),
      balanceMsats:
          clearWalletInfo ? null : (balanceMsats ?? this.balanceMsats),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      supportedMethods: supportedMethods ?? this.supportedMethods,
      connectionHealthy: connectionHealthy ?? this.connectionHealthy,
      lastSuccessfulContact:
          lastSuccessfulContact ?? this.lastSuccessfulContact,
    );
  }

  @override
  List<Object?> get props => [
        status,
        walletAlias,
        balanceMsats,
        errorMessage,
        supportedMethods,
        connectionHealthy,
        lastSuccessfulContact,
      ];
}

enum NwcStatus { disconnected, connecting, connected, error }

/// Manages the NWC wallet connection lifecycle.
///
/// On initialization checks secure storage for a saved connection URI
/// and auto-reconnects if found. Provides auto-reconnect on connection
/// drops, periodic balance refresh, and real-time notification handling.
class NwcNotifier extends StateNotifier<NwcState> {
  final Ref _ref;
  final NwcStorage _storage;
  NwcClient? _client;

  /// Saved URI for auto-reconnect.
  String? _savedUri;

  /// Subscription to NWC notification events.
  StreamSubscription<NwcNotification>? _notificationSub;

  /// Timer for periodic balance refresh.
  Timer? _balanceRefreshTimer;

  /// Timer for connection health checks.
  Timer? _healthCheckTimer;

  /// Number of consecutive reconnect attempts.
  int _reconnectAttempts = 0;

  /// Whether a reconnect loop is currently running.
  bool _isReconnecting = false;

  /// Maximum reconnect attempts before giving up.
  static const int _maxReconnectAttempts = 5;

  /// Controller for notification events exposed to the UI.
  final StreamController<NwcNotification> _notificationStreamController =
      StreamController<NwcNotification>.broadcast();

  /// Stream of payment notifications for UI consumption.
  Stream<NwcNotification> get notifications =>
      _notificationStreamController.stream;

  NwcNotifier(this._ref, this._storage) : super(const NwcState()) {
    _autoReconnect();
  }

  /// Attempts to restore a previous connection from secure storage.
  Future<void> _autoReconnect() async {
    try {
      final uri = await _storage.readConnection();
      if (uri != null && uri.isNotEmpty) {
        await connect(uri, persist: false);
      }
    } catch (e) {
      logger.w('NWC: Auto-reconnect failed: $e');
    }
  }

  /// Connects to a wallet using the given NWC URI.
  ///
  /// If [persist] is true (default), the URI is saved to secure storage.
  Future<void> connect(String uri, {bool persist = true}) async {
    state = state.copyWith(status: NwcStatus.connecting, clearError: true);

    try {
      final connection = NwcConnection.fromUri(uri);
      final nostrService = _ref.read(nostrServiceProvider);

      _cleanup();
      _client = NwcClient(
        connection: connection,
        nostrService: nostrService,
      );

      await _client!.connect();
      _savedUri = uri;

      // Fetch wallet info and balance
      GetInfoResult? info;
      GetBalanceResult? balance;

      try {
        info = await _client!.getInfo();
      } catch (e) {
        logger.w('NWC: get_info failed: $e');
      }

      try {
        balance = await _client!.getBalance();
      } catch (e) {
        logger.w('NWC: get_balance failed: $e');
      }

      if (persist) {
        try {
          await _storage.saveConnection(uri);
        } catch (e) {
          logger.w('NWC: Failed to persist connection URI: $e');
        }
      }

      state = NwcState(
        status: NwcStatus.connected,
        walletAlias: info?.alias,
        balanceMsats: balance?.balance,
        supportedMethods: info?.methods ?? [],
        connectionHealthy: true,
        lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
      );

      _reconnectAttempts = 0;

      // Subscribe to wallet notifications
      _subscribeToNotifications();

      // Start periodic balance refresh (every 60 seconds)
      _startBalanceRefresh();

      // Start connection health checks (every 30 seconds)
      _startHealthChecks();

      logger.i('NWC: Connected to wallet "${info?.alias ?? "unknown"}"');
    } on NwcInvalidUriException catch (e) {
      state = NwcState(
        status: NwcStatus.error,
        errorMessage: e.message,
      );
    } on NwcException catch (e) {
      state = NwcState(
        status: NwcStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      logger.e('NWC: Unexpected connection error: $e');
      state = const NwcState(
        status: NwcStatus.error,
        errorMessage: 'An unexpected error occurred while connecting',
      );
    }
  }

  /// Subscribes to real-time notification events from the wallet.
  void _subscribeToNotifications() {
    _notificationSub?.cancel();
    _notificationSub = _client?.notifications.listen(
      (notification) {
        logger
            .i('NWC: Notification received: ${notification.notificationType}');

        state = state.copyWith(
          lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
          connectionHealthy: true,
        );

        // Refresh balance on payment events
        if (notification.notificationType == 'payment_received' ||
            notification.notificationType == 'payment_sent') {
          refreshBalance();
        }

        // Forward to UI stream
        _notificationStreamController.add(notification);
      },
      onError: (Object error) {
        logger.w('NWC: Notification stream error: $error');
        _handleConnectionDrop();
      },
    );
  }

  /// Starts periodic balance refresh.
  void _startBalanceRefresh() {
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => refreshBalance(),
    );
  }

  /// Starts periodic connection health checks.
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkHealth(),
    );
  }

  /// Checks connection health by attempting a get_balance call.
  Future<void> _checkHealth() async {
    if (_client == null || !_client!.isConnected) {
      _handleConnectionDrop();
      return;
    }

    try {
      await _client!.getBalance();
      if (!state.connectionHealthy) {
        state = state.copyWith(
          connectionHealthy: true,
          lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } on NwcTimeoutException {
      logger.w('NWC: Health check timed out');
      state = state.copyWith(connectionHealthy: false);
      _handleConnectionDrop();
    } catch (e) {
      logger.w('NWC: Health check failed: $e');
      state = state.copyWith(connectionHealthy: false);
    }
  }

  /// Handles a detected connection drop with auto-reconnect.
  ///
  /// Uses an internal retry loop with exponential backoff and a
  /// reentrancy guard to prevent concurrent reconnect attempts.
  Future<void> _handleConnectionDrop() async {
    if (_savedUri == null ||
        _reconnectAttempts >= _maxReconnectAttempts ||
        state.status == NwcStatus.connecting ||
        _isReconnecting) {
      return;
    }

    _isReconnecting = true;
    state = state.copyWith(connectionHealthy: false);

    try {
      while (_reconnectAttempts < _maxReconnectAttempts &&
          _savedUri != null &&
          mounted) {
        _reconnectAttempts++;
        logger.i(
            'NWC: Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts');

        // Exponential backoff: 2s, 4s, 8s, 16s, 32s
        final delay = Duration(seconds: 1 << _reconnectAttempts);
        await Future<void>.delayed(delay);

        if (!mounted) break;

        try {
          await connect(_savedUri!, persist: false);
          // connect succeeded — timers restarted, attempts reset inside connect
          return;
        } catch (e) {
          logger.w('NWC: Reconnect attempt $_reconnectAttempts failed: $e');
        }
      }

      if (_reconnectAttempts >= _maxReconnectAttempts) {
        logger.w('NWC: Max reconnect attempts reached, giving up');
      }
    } finally {
      _isReconnecting = false;
    }
  }

  /// Disconnects from the wallet and clears stored connection.
  Future<void> disconnect() async {
    _cleanup();
    _savedUri = null;
    try {
      await _storage.deleteConnection();
    } catch (e) {
      logger.w('NWC: Failed to delete stored connection: $e');
    }
    state = const NwcState(status: NwcStatus.disconnected);
    logger.i('NWC: Disconnected and cleared stored connection');
  }

  /// Cleans up client, subscriptions, and timers.
  void _cleanup() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _client?.disconnect();
    _client = null;
  }

  /// Performs a pre-flight balance check before payment.
  ///
  /// Returns `true` if the wallet has sufficient balance for the given
  /// [amountSats]. Also refreshes the cached balance. Returns `true`
  /// if balance cannot be determined (let the wallet decide).
  Future<bool> preFlightBalanceCheck(int amountSats) async {
    if (_client == null || !_client!.isConnected) return true;

    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(
        balanceMsats: balance.balance,
        lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
        connectionHealthy: true,
      );
      final amountMsats = amountSats * 1000;
      return balance.balance >= amountMsats;
    } catch (e) {
      logger.w('NWC: Pre-flight balance check failed: $e');
      return true; // Let the wallet decide
    }
  }

  /// Pays a Lightning invoice via the connected NWC wallet.
  ///
  /// Throws [NwcNotConnectedException] if no wallet is connected.
  /// Throws [NwcResponseException] if the wallet returns an error.
  /// Throws [NwcTimeoutException] if the payment times out.
  Future<PayInvoiceResult> payInvoice(String invoice) async {
    if (_client == null || !_client!.isConnected) {
      throw const NwcNotConnectedException('No wallet connected');
    }

    final result = await _client!.payInvoice(
      PayInvoiceParams(invoice: invoice),
    );

    state = state.copyWith(
      lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
      connectionHealthy: true,
    );

    // Refresh balance after successful payment
    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(balanceMsats: balance.balance);
    } catch (e) {
      logger.w('NWC: Failed to refresh balance after payment: $e');
    }

    return result;
  }

  /// Creates a Lightning invoice via the connected NWC wallet.
  ///
  /// [amountSats] is the amount in satoshis (converted to msats for NWC).
  /// [description] is an optional memo for the invoice.
  ///
  /// Throws [NwcNotConnectedException] if no wallet is connected.
  /// Throws [NwcResponseException] if the wallet returns an error.
  /// Throws [NwcTimeoutException] if the request times out.
  Future<TransactionResult> makeInvoice(
    int amountSats, {
    String? description,
    int? expiry,
  }) async {
    if (_client == null || !_client!.isConnected) {
      throw const NwcNotConnectedException('No wallet connected');
    }

    final result = await _client!.makeInvoice(
      MakeInvoiceParams(
        amount: amountSats * 1000, // convert sats to msats
        description: description,
        expiry: expiry,
      ),
    );

    state = state.copyWith(
      lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
      connectionHealthy: true,
    );

    // Refresh balance after invoice creation
    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(balanceMsats: balance.balance);
    } catch (e) {
      logger.w('NWC: Failed to refresh balance after make_invoice: $e');
    }

    return result;
  }

  /// Looks up an invoice on the wallet side to verify payment status.
  ///
  /// Can be used after paying to cross-reference with Mostro's confirmation.
  Future<TransactionResult?> lookupInvoice({
    String? paymentHash,
    String? invoice,
  }) async {
    if (_client == null || !_client!.isConnected) return null;

    try {
      final result = await _client!.lookupInvoice(
        LookupInvoiceParams(paymentHash: paymentHash, invoice: invoice),
      );

      state = state.copyWith(
        lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
        connectionHealthy: true,
      );

      return result;
    } catch (e) {
      logger.w('NWC: lookup_invoice failed: $e');
      return null;
    }
  }

  /// Refreshes the wallet balance.
  Future<void> refreshBalance() async {
    if (_client == null || !_client!.isConnected) return;

    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(
        balanceMsats: balance.balance,
        lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
        connectionHealthy: true,
      );
    } catch (e) {
      logger.w('NWC: Failed to refresh balance: $e');
    }
  }

  /// Refreshes wallet info (alias, supported methods, etc.).
  Future<void> refreshInfo() async {
    if (_client == null || !_client!.isConnected) return;

    try {
      final info = await _client!.getInfo();
      state = state.copyWith(
        walletAlias: info.alias,
        supportedMethods: info.methods,
        lastSuccessfulContact: DateTime.now().millisecondsSinceEpoch,
        connectionHealthy: true,
      );
    } catch (e) {
      logger.w('NWC: Failed to refresh info: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    _notificationStreamController.close();
    super.dispose();
  }
}

/// Provider for the NWC storage layer.
final nwcStorageProvider = Provider<NwcStorage>((ref) {
  return NwcStorage(
    secureStorage: const FlutterSecureStorage(),
  );
});

/// Provider for the NWC wallet connection state.
final nwcProvider = StateNotifierProvider<NwcNotifier, NwcState>((ref) {
  final storage = ref.watch(nwcStorageProvider);
  return NwcNotifier(ref, storage);
});
