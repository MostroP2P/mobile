import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:nip44/nip44.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/services/nwc/nwc_models.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Core NWC client that communicates with a wallet service over Nostr relays.
///
/// Uses the connection parameters from [NwcConnection] to sign request events
/// (kind 23194) with the connection secret and encrypt/decrypt payloads using
/// NIP-44 as specified in NIP-47.
///
/// Accepts a [NostrService] dependency for relay interactions, following the
/// app's architectural pattern of routing all Nostr communication through
/// [NostrService] rather than accessing [Nostr.instance] directly.
class NwcClient {
  /// The parsed NWC connection.
  final NwcConnection connection;

  /// Timeout for individual requests.
  final Duration requestTimeout;

  /// The NostrService used for relay interactions.
  /// NWC wallet relays may differ from the app's Mostro relays, but relay
  /// connections are managed through the same [NostrService] to maintain
  /// consistency with the app's architecture.
  // ignore: unused_field
  final NostrService _nostrService;

  /// The key pair derived from the connection secret.
  late final NostrKeyPairs _keyPair;

  /// The public key of the client (derived from the secret).
  late final String _clientPubkey;

  /// Whether the client is currently connected to relays.
  bool _isConnected = false;

  /// The underlying Nostr instance.
  ///
  /// Currently accesses [Nostr.instance] directly since [NostrService] does
  /// not expose granular relay subscription methods. The [_nostrService]
  /// dependency is injected for future refactoring where NWC may use a
  /// dedicated Nostr instance with its own relay connections.
  Nostr get _nostr => Nostr.instance;

  /// Active subscriptions for response events.
  final Map<String, StreamSubscription<NostrEvent>> _subscriptions = {};

  NwcClient({
    required this.connection,
    required NostrService nostrService,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _nostrService = nostrService {
    _keyPair = NostrUtils.generateKeyPairFromPrivateKey(connection.secret);
    _clientPubkey = _keyPair.public;
  }

  /// Whether the client is currently connected.
  bool get isConnected => _isConnected;

  /// The client's public key (derived from the connection secret).
  String get clientPubkey => _clientPubkey;

  /// Connects to the wallet service's relay(s).
  ///
  /// This uses the existing Nostr relay infrastructure. If the wallet relay
  /// is already connected (e.g., same relay as Mostro), it will reuse it.
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      logger.i('NWC: Connecting to relays: ${connection.relayUrls}');

      await _nostr.services.relays.init(
        relaysUrl: connection.relayUrls,
        connectionTimeout: const Duration(seconds: 10),
        shouldReconnectToRelayOnNotice: true,
        retryOnClose: true,
        retryOnError: true,
        onRelayConnectionError: (relay, error, channel) {
          logger.w('NWC: Failed to connect to relay $relay: $error');
        },
        onRelayConnectionDone: (relay, socket) {
          logger.i('NWC: Connected to relay: $relay');
        },
      );

      _isConnected = true;
      logger.i('NWC: Connected successfully');
    } catch (e) {
      logger.e('NWC: Connection failed: $e');
      throw NwcNotConnectedException('Failed to connect: $e');
    }
  }

  /// Disconnects and cleans up all NWC subscriptions.
  ///
  /// Cancels all active event subscriptions and closes them on the relay side.
  ///
  /// **Relay connection note:** `Nostr.instance` is a shared singleton — its
  /// `disconnectFromRelays()` API closes *all* relay WebSockets (including
  /// Mostro's), and `dart_nostr` does not support closing individual relay
  /// connections. Until NWC gets its own dedicated Nostr instance (future
  /// refactor), NWC relay WebSocket connections that are not shared with
  /// Mostro will persist until the app is closed. This is a known limitation
  /// tracked for Phase 2.
  void disconnect() {
    // Cancel all active subscriptions and close them on the relay
    for (final entry in _subscriptions.entries) {
      entry.value.cancel();
      try {
        _nostr.services.relays.closeEventsSubscription(entry.key);
      } catch (e) {
        logger.w('NWC: Failed to close subscription ${entry.key}: $e');
      }
    }
    _subscriptions.clear();
    _isConnected = false;
    logger.i('NWC: Disconnected and cleaned up subscriptions');
  }

  /// Pays a Lightning invoice.
  ///
  /// Returns the payment preimage and optional fees paid.
  Future<PayInvoiceResult> payInvoice(PayInvoiceParams params) async {
    final response = await _sendRequest(NwcRequest(
      method: 'pay_invoice',
      params: params.toMap(),
    ));

    final result = response.result;
    if (result == null) {
      throw const NwcException(
          'pay_invoice: wallet returned success with null result');
    }
    return PayInvoiceResult.fromMap(result);
  }

  /// Creates a new Lightning invoice.
  ///
  /// Returns the transaction details including the encoded invoice.
  Future<TransactionResult> makeInvoice(MakeInvoiceParams params) async {
    final response = await _sendRequest(NwcRequest(
      method: 'make_invoice',
      params: params.toMap(),
    ));

    final result = response.result;
    if (result == null) {
      throw const NwcException(
          'make_invoice: wallet returned success with null result');
    }
    return TransactionResult.fromMap(result);
  }

  /// Gets the wallet balance in millisatoshis.
  Future<GetBalanceResult> getBalance() async {
    final response = await _sendRequest(const NwcRequest(
      method: 'get_balance',
      params: {},
    ));

    final result = response.result;
    if (result == null) {
      throw const NwcException(
          'get_balance: wallet returned success with null result');
    }
    return GetBalanceResult.fromMap(result);
  }

  /// Gets wallet information including supported methods.
  Future<GetInfoResult> getInfo() async {
    final response = await _sendRequest(const NwcRequest(
      method: 'get_info',
      params: {},
    ));

    final result = response.result;
    if (result == null) {
      throw const NwcException(
          'get_info: wallet returned success with null result');
    }
    return GetInfoResult.fromMap(result);
  }

  /// Looks up an invoice by payment hash or bolt11 string.
  Future<TransactionResult> lookupInvoice(LookupInvoiceParams params) async {
    final response = await _sendRequest(NwcRequest(
      method: 'lookup_invoice',
      params: params.toMap(),
    ));

    final result = response.result;
    if (result == null) {
      throw const NwcException(
          'lookup_invoice: wallet returned success with null result');
    }
    return TransactionResult.fromMap(result);
  }

  /// Sends a NWC request and waits for the response.
  ///
  /// 1. Encrypts the request payload with NIP-44
  /// 2. Creates a kind 23194 event signed with the connection secret
  /// 3. Subscribes to kind 23195 responses tagged with the request event ID
  /// 4. Publishes the request event
  /// 5. Waits for the response or times out
  Future<NwcResponse> _sendRequest(NwcRequest request) async {
    if (!_isConnected) {
      throw const NwcNotConnectedException();
    }

    final completer = Completer<NwcResponse>();

    try {
      // Encrypt the request payload using NIP-44
      final plaintext = request.toJson();
      final encrypted = await Nip44.encryptMessage(
        plaintext,
        connection.secret,
        connection.walletPubkey,
      );

      // Create the kind 23194 request event
      final requestEvent = NostrEvent.fromPartialData(
        kind: 23194,
        content: encrypted,
        keyPairs: _keyPair,
        tags: [
          ['p', connection.walletPubkey],
          ['encryption', 'nip44_v2'],
        ],
      );

      final requestId = requestEvent.id!;
      logger.d('NWC: Sending ${request.method} request (id: $requestId)');

      // Subscribe to response events (kind 23195) from the wallet service.
      // Only filter by kind + author; some NWC relay implementations
      // (e.g. Primal) don't support #e / #p tag filters, so we verify
      // the e-tag match in the event handler below.
      final filter = NostrFilter(
        kinds: const [23195],
        authors: [connection.walletPubkey],
      );

      final subId = 'nwc_${requestId.substring(0, 8)}';
      final stream = _nostr.services.relays.startEventsSubscription(
        request: NostrRequest(
          subscriptionId: subId,
          filters: [filter],
        ),
      );

      final subscription = stream.stream.listen((event) async {
        try {
          logger.d('NWC: Received event kind=${event.kind} from ${event.pubkey!.substring(0, 8)}...');

          // Verify this response references our request via 'e' tag
          final eTag = event.tags?.firstWhere(
            (t) => t.isNotEmpty && t[0] == 'e',
            orElse: () => [],
          );

          if (eTag == null || eTag.length < 2 || eTag[1] != requestId) {
            logger.d('NWC: Ignoring event — e tag mismatch (expected: ${requestId.substring(0, 8)}..., got: ${eTag != null && eTag.length >= 2 ? eTag[1].substring(0, 8) : "none"}...)');
            return; // Not our response
          }

          logger.d('NWC: Response matched for ${request.method}!');

          // Decrypt the response
          final decrypted = await Nip44.decryptMessage(
            event.content!,
            connection.secret,
            connection.walletPubkey,
          );

          final response = NwcResponse.fromJson(decrypted);

          if (!completer.isCompleted) {
            completer.complete(response);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(
              NwcException('Failed to process response: $e'),
            );
          }
        }
      });

      _subscriptions[subId] = subscription;

      // Publish the request event
      await _nostr.services.relays.sendEventToRelaysAsync(
        requestEvent,
        timeout: const Duration(seconds: 10),
      );

      NwcResponse response;
      try {
        // Wait for response with timeout
        logger.d('NWC: Waiting for ${request.method} response (timeout: ${requestTimeout.inSeconds}s)...');
        response = await completer.future.timeout(
          requestTimeout,
          onTimeout: () {
            logger.w('NWC: ${request.method} TIMED OUT after ${requestTimeout.inSeconds}s');
            throw NwcTimeoutException(
              '${request.method} request timed out after ${requestTimeout.inSeconds}s',
            );
          },
        );
      } finally {
        // Always clean up subscription, even on timeout or error
        await _subscriptions[subId]?.cancel();
        _subscriptions.remove(subId);
        _nostr.services.relays.closeEventsSubscription(subId);
      }

      // Check for error response
      if (!response.isSuccess) {
        throw NwcResponseException(
          response.error!.code,
          response.error!.message,
        );
      }

      logger.d('NWC: ${request.method} completed successfully');
      return response;
    } catch (e) {
      if (e is NwcException) rethrow;
      throw NwcException('Request failed: $e');
    }
  }
}
