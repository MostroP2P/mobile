import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/relay_informations.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

class NostrService {
  late Settings settings;
  final Nostr _nostr = Nostr.instance;
  final Logger _logger = Logger();
  bool _isInitialized = false;

  NostrService();

  Future<void> init(Settings settings) async {
    this.settings = settings;
    try {
      await _nostr.services.relays.init(
        relaysUrl: settings.relays,
        connectionTimeout: Config.nostrConnectionTimeout,
        shouldReconnectToRelayOnNotice: true,
        retryOnClose: true,
        retryOnError: true,
        onRelayListening: (relayUrl, receivedData, channel) {
          if (receivedData is NostrEvent) {
            _logger.i('Event from $relayUrl: ${receivedData.content}');
          } else if (receivedData is NostrNotice) {
            _logger.i('Notice from $relayUrl: ${receivedData.message}');
          } else if (receivedData is NostrEventOkCommand) {
            _logger.i(
                'OK from $relayUrl: ${receivedData.eventId} (accepted: ${receivedData.isEventAccepted})');
          } else if (receivedData is NostrRequestEoseCommand) {
            _logger.i(
                'EOSE from $relayUrl for subscription: ${receivedData.subscriptionId}');
          } else if (receivedData is NostrCountResponse) {
            _logger.i('Count from $relayUrl: ${receivedData.count}');
          }
        },
        onRelayConnectionError: (relay, error, channel) {
          _logger.w('Failed to connect to relay $relay: $error');
        },
        onRelayConnectionDone: (relay, socket) {
          _logger.i('Connection to relay: $relay via $socket is done');
        },
      );
      _isInitialized = true;
      _logger.i('Nostr initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Nostr: $e');
      rethrow;
    }
  }

  Future<void> updateSettings(Settings newSettings) async {
    final relays = Nostr.instance.services.relays.relaysList;
    if (!ListEquality().equals(relays, newSettings.relays)) {
      _logger.i('Updating relays...');
      await init(newSettings);
    }
  }

  Future<RelayInformations?> getRelayInfo(String relayUrl) async {
    return await Nostr.instance.services.relays.relayInformationsDocumentNip11(
      relayUrl: relayUrl,
    );
  }

  Future<void> publishEvent(NostrEvent event) async {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    try {
      await _nostr.services.relays.sendEventToRelaysAsync(
        event,
        timeout: Config.nostrConnectionTimeout,
      );
    } catch (e) {
      _logger.w('Failed to publish event: $e');
      rethrow;
    }
  }

  Stream<NostrEvent> subscribeToEvents(NostrRequest request) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    final subscription =
        _nostr.services.relays.startEventsSubscription(request: request);

    return subscription.stream;
  }

  Future<void> disconnectFromRelays() async {
    if (!_isInitialized) return;

    await _nostr.services.relays.disconnectFromRelays();
    _isInitialized = false;
    _logger.i('Disconnected from all relays');
  }

  bool get isInitialized => _isInitialized;

  void unsubscribe(String id) {
    if (!_isInitialized) {
      throw Exception('Nostr is not initialized. Call init() first.');
    }

    _nostr.services.relays.closeEventsSubscription(id);
  }
}
