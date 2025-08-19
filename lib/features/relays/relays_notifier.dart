import 'dart:async';
import 'dart:io';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'relay.dart';

class RelayValidationResult {
  final bool success;
  final String? normalizedUrl;
  final String? error;
  final bool isHealthy;

  RelayValidationResult({
    required this.success,
    this.normalizedUrl,
    this.error,
    this.isHealthy = false,
  });
}

class RelaysNotifier extends StateNotifier<List<Relay>> {
  final SettingsNotifier settings;
  final Ref ref;
  final _logger = Logger();
  SubscriptionManager? _subscriptionManager;
  StreamSubscription<RelayListEvent>? _relayListSubscription;
  Timer? _settingsWatchTimer;

  RelaysNotifier(this.settings, this.ref) : super([]) {
    _loadRelays();
    _initMostroRelaySync();
    _initSettingsListener();
  }

  void _loadRelays() {
    final saved = settings.state;
    // Convert existing URL-only relays to new Relay objects with source information
    state = saved.relays.map((url) {
      // Check if this is a default relay
      if (url == 'wss://relay.mostro.network') {
        return Relay.fromDefault(url);
      }
      // Otherwise treat as user-added relay
      return Relay(url: url, source: RelaySource.user, addedAt: DateTime.now());
    }).toList();
  }

  Future<void> _saveRelays() async {
    final relays = state.map((r) => r.url).toList();
    await settings.updateRelays(relays);
  }

  Future<void> addRelay(Relay relay) async {
    state = [...state, relay];
    await _saveRelays();
  }

  Future<void> updateRelay(Relay oldRelay, Relay updatedRelay) async {
    state = state.map((r) => r.url == oldRelay.url ? updatedRelay : r).toList();
    await _saveRelays();
  }

  Future<void> removeRelay(String url) async {
    state = state.where((r) => r.url != url).toList();
    await _saveRelays();
  }

  /// Smart URL normalization - handles different input formats
  String? normalizeRelayUrl(String input) {
    input = input.trim().toLowerCase();

    if (!isValidDomainFormat(input)) return null;

    if (input.startsWith('wss://')) {
      return input; // Already properly formatted
    } else if (input.startsWith('ws://') || input.startsWith('http')) {
      return null; // Reject non-secure protocols
    } else {
      return 'wss://$input'; // Auto-add wss:// prefix
    }
  }

  /// Domain validation using RegExp
  bool isValidDomainFormat(String input) {
    // Remove protocol prefix if present
    if (input.startsWith('wss://')) {
      input = input.substring(6);
    } else if (input.startsWith('ws://')) {
      input = input.substring(5);
    } else if (input.startsWith('http://')) {
      input = input.substring(7);
    } else if (input.startsWith('https://')) {
      input = input.substring(8);
    }

    // Reject IP addresses (basic check for numbers and dots only)
    if (RegExp(r'^[\d.]+$').hasMatch(input)) {
      return false;
    }

    // Domain regex: valid domain format with at least one dot
    final domainRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');
    return domainRegex.hasMatch(input) && input.contains('.');
  }

  /// Test connectivity using proper Nostr protocol validation
  /// Sends REQ message and waits for EVENT + EOSE responses
  Future<bool> testRelayConnectivity(String url) async {
    // First try full protocol test
    bool protocolResult = await _testNostrProtocol(url);
    if (protocolResult) {
      return true;
    }

    // If protocol test fails, try basic WebSocket connectivity as fallback
    return await _testBasicWebSocketConnectivity(url);
  }

  /// Full Nostr protocol test - preferred method
  Future<bool> _testNostrProtocol(String url) async {
    // Generate unique subscription ID for this test
    final testSubId = 'relay_test_${DateTime.now().millisecondsSinceEpoch}';
    bool receivedEvent = false;
    bool receivedEose = false;
    bool isConnected = false;

    try {
      // Create isolated instance for testing
      final testNostr = Nostr();

      // Setup listeners to track EVENT and EOSE responses
      await testNostr.services.relays.init(
        relaysUrl: [url],
        connectionTimeout: const Duration(seconds: 5),
        shouldReconnectToRelayOnNotice: false,
        retryOnClose: false,
        retryOnError: false,
        onRelayListening: (relayUrl, receivedData, channel) {
          // Track EVENT and EOSE responses

          // Check for EVENT message with our subscription ID
          if (receivedData is NostrEvent &&
              receivedData.subscriptionId == testSubId) {
            // Found an event for our subscription
            receivedEvent = true;
          }
          // Check for EOSE message with our subscription ID
          else if (receivedData is NostrRequestEoseCommand &&
              receivedData.subscriptionId == testSubId) {
            // Found end of stored events for our subscription
            receivedEose = true;
          }
        },
        onRelayConnectionDone: (relay, socket) {
          if (relay == url) {
            // Successfully connected to relay
            isConnected = true;
          }
        },
        onRelayConnectionError: (relay, error, channel) {
          // Connection failed - relay is not reachable
          isConnected = false;
        },
      );

      // Wait for connection establishment (max 5 seconds)
      int connectionWaitCount = 0;
      while (!isConnected && connectionWaitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        connectionWaitCount++;
      }

      if (!isConnected) {
        // Failed to connect within timeout
        await _cleanupTestConnection(testNostr);
        return false;
      }

      // Send REQ message to test relay response
      final filter = NostrFilter(kinds: [1], limit: 1);
      final request = NostrRequest(
        subscriptionId: testSubId,
        filters: [filter],
      );

      // Send the request
      await testNostr.services.relays.startEventsSubscriptionAsync(
        request: request,
        timeout: const Duration(seconds: 3),
      );

      // Wait for EVENT or EOSE responses (max 8 seconds total)
      int waitCount = 0;
      while (!receivedEvent && !receivedEose && waitCount < 80) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      // Protocol test completed

      // Clean up connection
      await _cleanupTestConnection(testNostr);

      // Relay is healthy if we received either EVENT or EOSE (or both)
      return receivedEvent || receivedEose;
    } catch (e) {
      // Protocol test failed with error
      try {
        await _cleanupTestConnection(Nostr.instance);
      } catch (_) {
        // Ignore cleanup errors
      }
      return false;
    }
  }

  /// Basic WebSocket connectivity test as fallback
  Future<bool> _testBasicWebSocketConnectivity(String url) async {
    try {
      // Simple WebSocket connection test
      final uri = Uri.parse(url);
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: {'User-Agent': 'MostroMobile/1.0'},
      ).timeout(const Duration(seconds: 8));

      // Send a basic REQ message to test if it's a Nostr relay
      const testReq = '["REQ", "test_conn", {"kinds":[1], "limit":1}]';
      socket.add(testReq);

      // Wait for any response (max 5 seconds)
      bool receivedResponse = false;
      final subscription = socket.listen(
        (message) {
          // Received WebSocket message
          // Any valid JSON response indicates a working relay
          if (message.toString().startsWith('["')) {
            receivedResponse = true;
          }
        },
        onError: (error) {
          // WebSocket connection error
        },
      );

      // Wait for response
      int waitCount = 0;
      while (!receivedResponse && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      // WebSocket test completed

      // Cleanup
      await subscription.cancel();
      await socket.close();

      return receivedResponse;
    } catch (e) {
      // WebSocket test failed
      return false;
    }
  }

  /// Helper method to clean up test connections
  Future<void> _cleanupTestConnection(Nostr nostrInstance) async {
    try {
      await nostrInstance.services.relays.disconnectFromRelays();
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  /// Smart relay addition with full validation
  /// Only adds relays that pass BOTH format validation AND connectivity test
  /// Automatically removes relay from blacklist if user manually adds it
  Future<RelayValidationResult> addRelayWithSmartValidation(
    String input, {
    required String errorOnlySecure,
    required String errorNoHttp,
    required String errorInvalidDomain,
    required String errorAlreadyExists,
    required String errorNotValid,
  }) async {
    // Step 1: Normalize URL
    final normalizedUrl = normalizeRelayUrl(input);
    if (normalizedUrl == null) {
      if (input.trim().toLowerCase().startsWith('ws://')) {
        return RelayValidationResult(
          success: false,
          error: errorOnlySecure,
        );
      } else if (input.trim().toLowerCase().startsWith('http')) {
        return RelayValidationResult(
          success: false,
          error: errorNoHttp,
        );
      } else {
        return RelayValidationResult(
          success: false,
          error: errorInvalidDomain,
        );
      }
    }

    // Step 2: Check for duplicates
    if (state.any((relay) => relay.url == normalizedUrl)) {
      return RelayValidationResult(
        success: false,
        error: errorAlreadyExists,
      );
    }

    // Step 3: Test connectivity using dart_nostr - MUST PASS to proceed
    final isHealthy = await testRelayConnectivity(normalizedUrl);

    // Step 4: Only add relay if it passes connectivity test
    if (!isHealthy) {
      return RelayValidationResult(
        success: false,
        error: errorNotValid,
      );
    }

    // Step 5: Remove from blacklist if present (user wants to manually add it)
    if (settings.state.blacklistedRelays.contains(normalizedUrl)) {
      await settings.removeFromBlacklist(normalizedUrl);
      _logger.i('Removed $normalizedUrl from blacklist - user manually added it');
    }

    // Step 6: Add relay as user relay (overrides any previous Mostro source)
    final newRelay = Relay(
      url: normalizedUrl, 
      isHealthy: true,
      source: RelaySource.user,
      addedAt: DateTime.now(),
    );
    state = [...state, newRelay];
    await _saveRelays();

    return RelayValidationResult(
      success: true,
      normalizedUrl: normalizedUrl,
      isHealthy: true,
    );
  }

  Future<void> refreshRelayHealth() async {
    final updatedRelays = <Relay>[];

    for (final relay in state) {
      final isHealthy = await testRelayConnectivity(relay.url);
      updatedRelays.add(relay.copyWith(isHealthy: isHealthy));
    }

    state = updatedRelays;
    await _saveRelays();
  }

  /// Initialize Mostro relay synchronization
  void _initMostroRelaySync() {
    try {
      _subscriptionManager = SubscriptionManager(ref);
      
      // Subscribe to relay list events
      _relayListSubscription = _subscriptionManager!.relayList.listen(
        (relayListEvent) {
          _handleMostroRelayListUpdate(relayListEvent);
        },
        onError: (error, stackTrace) {
          _logger.e('Error handling relay list event',
              error: error, stackTrace: stackTrace);
        },
      );

      // Start syncing with the current Mostro instance
      syncWithMostroInstance();
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize Mostro relay sync',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Synchronize relays with the configured Mostro instance
  Future<void> syncWithMostroInstance() async {
    try {
      final mostroPubkey = settings.state.mostroPublicKey;
      if (mostroPubkey.isEmpty) {
        _logger.w('No Mostro pubkey configured, skipping relay sync');
        return;
      }

      _logger.i('Syncing relays with Mostro instance: $mostroPubkey');
      
      // Cancel any existing relay list subscription before creating new one
      _subscriptionManager?.unsubscribeFromMostroRelayList();
      
      // Clean existing Mostro relays from state to prevent contamination
      _cleanMostroRelaysFromState();
      
      // Subscribe to the new Mostro instance
      _subscriptionManager?.subscribeToMostroRelayList(mostroPubkey);
    } catch (e, stackTrace) {
      _logger.e('Failed to sync with Mostro instance',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Handle relay list updates from Mostro instance
  void _handleMostroRelayListUpdate(RelayListEvent event) {
    try {
      final currentMostroPubkey = settings.state.mostroPublicKey;
      
      // Validate that this event is from the currently configured Mostro instance
      if (event.authorPubkey != currentMostroPubkey) {
        _logger.w('Ignoring relay list event from wrong Mostro instance. '
            'Expected: $currentMostroPubkey, Got: ${event.authorPubkey}');
        return;
      }
      
      _logger.i('Received relay list from Mostro ${event.authorPubkey}: ${event.relays}');
      
      // Normalize relay URLs to prevent duplicates
      final normalizedRelays = event.validRelays
          .map((url) => _normalizeRelayUrl(url))
          .toSet() // Remove duplicates
          .toList();
      
      // Get current relays grouped by source
      final currentRelays = <String, Relay>{
        for (final relay in state) relay.url: relay,
      };

      // Get blacklisted relays from settings
      final blacklistedUrls = settings.state.blacklistedRelays;

      // Remove old Mostro relays that are no longer in the list
      final updatedRelays = state.where((relay) => relay.source != RelaySource.mostro).toList();
      
      // Add new Mostro relays (filtering out blacklisted ones)
      for (final relayUrl in normalizedRelays) {
        // Skip if blacklisted by user
        if (blacklistedUrls.contains(relayUrl)) {
          _logger.i('Skipping blacklisted Mostro relay: $relayUrl');
          continue;
        }

        // Skip if already exists (user or default relay)
        if (currentRelays.containsKey(relayUrl) && 
            currentRelays[relayUrl]!.source != RelaySource.mostro) {
          _logger.i('Relay already exists as ${currentRelays[relayUrl]!.source}: $relayUrl');
          continue;
        }
        
        // Add new Mostro relay
        final mostroRelay = Relay.fromMostro(relayUrl);
        updatedRelays.add(mostroRelay);
        _logger.i('Added Mostro relay: $relayUrl');
      }

      // Update state if there are changes
      if (updatedRelays.length != state.length || 
          !updatedRelays.every((relay) => state.contains(relay))) {
        state = updatedRelays;
        _saveRelays();
        _logger.i('Updated relay list with ${updatedRelays.length} relays (${blacklistedUrls.length} blacklisted)');
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling Mostro relay list update',
          error: e, stackTrace: stackTrace);
    }
  }


  /// Remove relay with blacklist support
  /// If it's a Mostro relay, it gets blacklisted to prevent re-addition
  /// If it's a user relay, it's simply removed
  Future<void> removeRelayWithBlacklist(String url) async {
    final relay = state.firstWhere((r) => r.url == url, orElse: () => Relay(url: ''));
    
    if (relay.url.isEmpty) {
      _logger.w('Attempted to remove non-existent relay: $url');
      return;
    }

    if (relay.source == RelaySource.mostro || relay.source == RelaySource.defaultConfig) {
      // Blacklist Mostro/default relays to prevent re-addition during sync
      await settings.addToBlacklist(url);
      _logger.i('Blacklisted ${relay.source} relay: $url');
    }

    // Remove relay from current state regardless of source
    await removeRelay(url);
    _logger.i('Removed relay: $url (source: ${relay.source})');
  }

  /// Remove relay (with source awareness) - deprecated, use removeRelayWithBlacklist
  @Deprecated('Use removeRelayWithBlacklist for better user experience')
  Future<void> removeRelayWithSource(String url) async {
    final relay = state.firstWhere((r) => r.url == url, orElse: () => Relay(url: ''));
    
    if (relay.url.isEmpty) return;

    // Only allow removal of user-added relays
    if (!relay.canDelete) {
      _logger.w('Cannot delete auto-discovered relay: $url');
      return;
    }

    await removeRelay(url);
  }

  /// Initialize settings listener to watch for Mostro pubkey changes
  void _initSettingsListener() {
    // Watch settings changes and re-sync when Mostro pubkey changes
    String? currentPubkey = settings.state.mostroPublicKey;
    
    // Use a simple timer to periodically check for changes
    // This avoids circular dependency issues with provider watching
    _settingsWatchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final newPubkey = settings.state.mostroPublicKey;
      if (newPubkey != currentPubkey) {
        _logger.i('Detected Mostro pubkey change: $currentPubkey -> $newPubkey');
        currentPubkey = newPubkey;
        syncWithMostroInstance();
      }
    });
  }

  /// Check if a relay URL is currently blacklisted
  bool isRelayBlacklisted(String url) {
    return settings.state.blacklistedRelays.contains(url);
  }

  /// Get all blacklisted relay URLs
  List<String> get blacklistedRelays => settings.blacklistedRelays;

  /// Clear all blacklisted relays and trigger re-sync
  Future<void> clearBlacklistAndResync() async {
    await settings.clearBlacklist();
    _logger.i('Cleared blacklist, triggering relay re-sync');
    await syncWithMostroInstance();
  }

  /// Clean existing Mostro relays from state when switching instances
  void _cleanMostroRelaysFromState() {
    final cleanedRelays = state.where((relay) => relay.source != RelaySource.mostro).toList();
    if (cleanedRelays.length != state.length) {
      state = cleanedRelays;
      _saveRelays();
      _logger.i('Cleaned ${state.length - cleanedRelays.length} Mostro relays from state');
    }
  }

  /// Normalize relay URL to prevent duplicates (removes trailing slash)
  String _normalizeRelayUrl(String url) {
    url = url.trim();
    // Remove trailing slash if present
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  void dispose() {
    _relayListSubscription?.cancel();
    _subscriptionManager?.dispose();
    _settingsWatchTimer?.cancel();
    super.dispose();
  }
}
