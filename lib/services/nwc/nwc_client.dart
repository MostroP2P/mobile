import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_crypto.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/services/nwc/nwc_models.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// A decoded NWC notification from the wallet (kind 23196).
class NwcNotification {
  /// The notification type (e.g., "payment_received", "payment_sent").
  final String notificationType;

  /// The notification payload (transaction details).
  final TransactionResult transaction;

  const NwcNotification({
    required this.notificationType,
    required this.transaction,
  });
}

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

  /// The encryption mode negotiated with the wallet service.
  ///
  /// Determined by the wallet's info event (kind 13194). If the info event
  /// contains an `encryption` tag with `nip44_v2`, NIP-44 is used. Otherwise,
  /// NIP-04 is assumed per the NIP-47 spec for backwards compatibility.
  NwcEncryption _encryptionMode = NwcEncryption.nip04;

  /// Dedicated Nostr instance for NWC relay communication.
  ///
  /// Uses a separate instance from [Nostr.instance] to avoid interference
  /// with Mostro's relay pool. This ensures subscriptions and events are
  /// sent only to the NWC wallet relay(s), not broadcast to all app relays.
  final Nostr _nostr = Nostr();

  /// Active subscriptions for response events.
  final Map<String, StreamSubscription<NostrEvent>> _subscriptions = {};

  /// Controller for NWC notification events (kind 23196).
  final StreamController<NwcNotification> _notificationController =
      StreamController<NwcNotification>.broadcast();

  /// Stream of real-time notifications from the wallet.
  ///
  /// Emits [NwcNotification] events for `payment_received`,
  /// `payment_sent`, etc. Subscribe after calling [connect].
  Stream<NwcNotification> get notifications => _notificationController.stream;

  /// Subscription ID for the notification listener.
  String? _notificationSubId;

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

      // Detect encryption mode from the wallet's info event (kind 13194).
      // Per NIP-47, if no encryption tag is present, assume NIP-04.
      await _detectEncryptionMode();
      logger.i('NWC: Using encryption mode: ${_encryptionMode.name}');

      // Subscribe to notification events (kind 23196) for real-time updates.
      _subscribeToNotifications();
    } catch (e) {
      logger.e('NWC: Connection failed: $e');
      throw NwcNotConnectedException('Failed to connect: $e');
    }
  }

  /// Whether [event] is a kind-[kind] event the wallet itself signed.
  ///
  /// Every NWC subscription names a kind and an author in its filter, but the
  /// pinned dart_nostr fork parses relay EVENT frames straight into a
  /// NostrEvent: it neither verifies the signature nor matches the frame
  /// against the filter that was sent. Both are therefore a statement of what
  /// was asked for, and the author on the way back is the relay's claim.
  ///
  /// The relay here is the one named in the user's own wallet URI — precisely
  /// the party NIP-47's encryption says you should not have to trust.
  @visibleForTesting
  bool isFromWallet(NostrEvent event, int kind) {
    if (event.kind != kind) return false;
    if (event.pubkey != connection.walletPubkey) return false;
    if (!NostrUtils.isValidEventSignature(event)) {
      logger.w(
        'NWC: ignoring kind-$kind event ${event.id} claiming to be from the '
        'wallet: signature verification failed',
      );
      return false;
    }
    return true;
  }

  /// Detects the wallet's supported encryption mode from its info event.
  Future<void> _detectEncryptionMode() async {
    try {
      final completer = Completer<NwcEncryption>();
      final subId = 'nwc_info_${DateTime.now().millisecondsSinceEpoch}';

      final stream = _nostr.services.relays.startEventsSubscription(
        request: NostrRequest(
          subscriptionId: subId,
          filters: [
            NostrFilter(
              kinds: const [13194],
              authors: [connection.walletPubkey],
              limit: 1,
            ),
          ],
        ),
      );

      final subscription = stream.stream.listen((event) {
        if (!isFromWallet(event, 13194)) return;

        // Look for the encryption tag
        final encTag = event.tags?.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'encryption',
          orElse: () => [],
        );

        NwcEncryption mode = NwcEncryption.nip04; // default per spec
        if (encTag != null && encTag.length >= 2) {
          final supported = encTag[1].split(' ');
          if (supported.contains('nip44_v2')) {
            mode = NwcEncryption.nip44;
          }
        }

        if (!completer.isCompleted) {
          completer.complete(mode);
        }
      });

      // Wait briefly for the info event (it's a replaceable event, should be fast)
      _encryptionMode = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          logger.w('NWC: No info event found, defaulting to NIP-04');
          return NwcEncryption.nip04;
        },
      );

      await subscription.cancel();
      _nostr.services.relays.closeEventsSubscription(subId);
    } catch (e) {
      logger
          .w('NWC: Failed to detect encryption mode: $e, defaulting to NIP-04');
      _encryptionMode = NwcEncryption.nip04;
    }
  }

  /// Subscribes to NWC notification events (kind 23196) from the wallet.
  ///
  /// NIP-47 defines kind 23196 as the notification event kind. The wallet
  /// sends these for events like `payment_received` and `payment_sent`.
  void _subscribeToNotifications() {
    _notificationSubId = 'nwc_notif_${DateTime.now().millisecondsSinceEpoch}';

    final stream = _nostr.services.relays.startEventsSubscription(
      request: NostrRequest(
        subscriptionId: _notificationSubId!,
        filters: [
          NostrFilter(
            kinds: const [23196],
            authors: [connection.walletPubkey],
            since: DateTime.now(),
          ),
        ],
      ),
    );

    final subscription = stream.stream.listen((event) async {
      try {
        if (!isFromWallet(event, 23196)) return;

        // Verify the notification is addressed to us via 'p' tag
        final pTag = event.tags?.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'p',
          orElse: () => [],
        );
        if (pTag == null || pTag.length < 2 || pTag[1] != _clientPubkey) {
          return; // Not for us
        }

        final responseMode = NwcCrypto.detectFromContent(event.content!);
        final decrypted = await NwcCrypto.decrypt(
          event.content!,
          connection.secret,
          connection.walletPubkey,
          responseMode,
        );

        final response = NwcResponse.fromJson(decrypted);
        if (response.result != null) {
          final notification = NwcNotification(
            notificationType: response.resultType,
            transaction: TransactionResult.fromMap(response.result!),
          );
          _notificationController.add(notification);
          logger.i(
              'NWC: Received notification: ${notification.notificationType}');
        }
      } catch (e) {
        logger.w('NWC: Failed to process notification: $e');
      }
    });

    _subscriptions[_notificationSubId!] = subscription;
    logger.i('NWC: Subscribed to wallet notifications (kind 23196)');
  }

  /// Disconnects from relays and cleans up all NWC subscriptions.
  ///
  /// Cancels all active event subscriptions, closes them on the relay side,
  /// and disconnects the dedicated NWC Nostr instance from all relays.
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

    // Disconnect the dedicated NWC relay connections
    try {
      _nostr.services.relays.disconnectFromRelays();
    } catch (e) {
      logger.w('NWC: Failed to disconnect relays: $e');
    }

    _notificationSubId = null;

    _isConnected = false;
    logger.i('NWC: Disconnected and cleaned up');
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
      // Encrypt the request payload using the negotiated encryption mode
      final plaintext = request.toJson();
      final encrypted = await NwcCrypto.encrypt(
        plaintext,
        connection.secret,
        connection.walletPubkey,
        _encryptionMode,
      );

      // Create the kind 23194 request event
      final encryptionTag = NwcCrypto.encryptionTagValue(_encryptionMode);
      final requestEvent = NostrEvent.fromPartialData(
        kind: 23194,
        content: encrypted,
        keyPairs: _keyPair,
        tags: [
          ['p', connection.walletPubkey],
          ['encryption', encryptionTag],
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
          if (!isFromWallet(event, 23195)) return;

          // Verify this response references our request via 'e' tag
          final eTag = event.tags?.firstWhere(
            (t) => t.isNotEmpty && t[0] == 'e',
            orElse: () => [],
          );

          if (eTag == null || eTag.length < 2 || eTag[1] != requestId) {
            logger.d(
                'NWC: Ignoring event — e tag mismatch (expected: ${requestId.substring(0, 8)}..., got: ${eTag != null && eTag.length >= 2 ? eTag[1].substring(0, 8) : "none"}...)');
            return; // Not our response
          }

          final content = event.content;
          if (content == null || content.isEmpty) {
            logger.w('NWC: ignoring response ${event.id} with no content');
            return;
          }

          logger.d('NWC: Response matched for ${request.method}!');

          // Decrypt the response using the detected encryption mode.
          // Auto-detect from content format as a safety fallback.
          final responseMode = NwcCrypto.detectFromContent(content);
          final decrypted = await NwcCrypto.decrypt(
            content,
            connection.secret,
            connection.walletPubkey,
            responseMode,
          );

          final response = NwcResponse.fromJson(decrypted);

          if (!completer.isCompleted) {
            completer.complete(response);
          }
        } catch (e) {
          // Ignore the event; never fail the request on one.
          //
          // The request id travels in the clear on the relay carrying it, so
          // addressing a reply to this request costs an attacker nothing.
          // Failing here surfaced "payment failed" before the wallet's real
          // response had a chance to arrive, and it is the user's retry that
          // costs money. The genuine response is still coming; only the
          // timeout ends this wait unsuccessfully.
          logger.w('NWC: ignoring unusable response event ${event.id}: $e');
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
        logger.d(
            'NWC: Waiting for ${request.method} response (timeout: ${requestTimeout.inSeconds}s)...');
        response = await completer.future.timeout(
          requestTimeout,
          onTimeout: () {
            logger.w(
                'NWC: ${request.method} TIMED OUT after ${requestTimeout.inSeconds}s');
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
