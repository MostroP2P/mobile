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

  const NwcState({
    this.status = NwcStatus.disconnected,
    this.walletAlias,
    this.balanceMsats,
    this.errorMessage,
    this.supportedMethods = const [],
  });

  /// Balance converted from millisatoshis to satoshis.
  int? get balanceSats =>
      balanceMsats != null ? (balanceMsats! ~/ 1000) : null;

  NwcState copyWith({
    NwcStatus? status,
    String? walletAlias,
    int? balanceMsats,
    String? errorMessage,
    List<String>? supportedMethods,
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
    );
  }

  @override
  List<Object?> get props =>
      [status, walletAlias, balanceMsats, errorMessage, supportedMethods];
}

enum NwcStatus { disconnected, connecting, connected, error }

/// Manages the NWC wallet connection lifecycle.
///
/// On initialization checks secure storage for a saved connection URI
/// and auto-reconnects if found.
class NwcNotifier extends StateNotifier<NwcState> {
  final Ref _ref;
  final NwcStorage _storage;
  NwcClient? _client;

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

      _client?.disconnect();
      _client = NwcClient(
        connection: connection,
        nostrService: nostrService,
      );

      await _client!.connect();

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
      );

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

  /// Disconnects from the wallet and clears stored connection.
  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
    try {
      await _storage.deleteConnection();
    } catch (e) {
      logger.w('NWC: Failed to delete stored connection: $e');
    }
    state = const NwcState(status: NwcStatus.disconnected);
    logger.i('NWC: Disconnected and cleared stored connection');
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

    // Refresh balance after successful payment
    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(balanceMsats: balance.balance);
    } catch (e) {
      logger.w('NWC: Failed to refresh balance after payment: $e');
    }

    return result;
  }

  /// Refreshes the wallet balance.
  Future<void> refreshBalance() async {
    if (_client == null || !_client!.isConnected) return;

    try {
      final balance = await _client!.getBalance();
      state = state.copyWith(balanceMsats: balance.balance);
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
      );
    } catch (e) {
      logger.w('NWC: Failed to refresh info: $e');
    }
  }

  @override
  void dispose() {
    _client?.disconnect();
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
