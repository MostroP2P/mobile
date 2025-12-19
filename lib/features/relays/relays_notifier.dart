import 'dart:async';
import 'dart:io';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
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
  SubscriptionManager? _subscriptionManager;
  StreamSubscription<RelayListEvent>? _relayListSubscription;
  Timer? _settingsWatchTimer;
  Timer? _retryTimer;  // Store retry timer to prevent leaks
  
  // Hash-based deduplication to prevent processing identical relay lists
  String? _lastRelayListHash;
  
  // Timestamp validation to ignore older events
  DateTime? _lastProcessedEventTime;

  RelaysNotifier(this.settings, this.ref) : super([]) {
    _loadRelays();
    _initMostroRelaySync();
    _initSettingsListener();
    
    // Defer sync to avoid circular dependency during provider initialization
    Future.microtask(() => syncWithMostroInstance());
  }

  void _loadRelays() {
    final saved = settings.state;
    
    logger.i('Loading relays from settings: ${saved.relays}');
    logger.i('Loading user relays from settings: ${saved.userRelays}');
    
    final loadedRelays = <Relay>[];
    
    // Always ensure default relay exists for initial connection
    final defaultRelay = Relay.fromDefault('wss://relay.mostro.network');
    loadedRelays.add(defaultRelay);
    
    // Load Mostro relays from settings.relays (excluding default to avoid duplicates)
    final relaysFromSettings = saved.relays
        .where((url) => url != 'wss://relay.mostro.network') // Avoid duplicates
        .map((url) => Relay.fromMostro(url))
        .toList();
    loadedRelays.addAll(relaysFromSettings);
    
    // Load user relays from settings.userRelays
    final userRelaysFromSettings = saved.userRelays
        .map((relayData) => Relay.fromJson(relayData))
        .where((relay) => relay.source == RelaySource.user) // Ensure they're marked as user relays
        .toList();
    loadedRelays.addAll(userRelaysFromSettings);
    
    state = loadedRelays;
    logger.i('Loaded ${state.length} relays: ${state.map((r) => '${r.url} (${r.source})').toList()}');
  }

  Future<void> _saveRelays() async {
    // Get blacklisted relays
    final blacklistedUrls = settings.state.blacklistedRelays;
    
    // Include ALL active relays (Mostro/default + user) that are NOT blacklisted
    final allActiveRelayUrls = state
        .where((r) => !blacklistedUrls.contains(r.url))
        .map((r) => r.url)
        .toList();
    
    // Separate user relays for metadata preservation
    final userRelays = state.where((r) => r.source == RelaySource.user).toList();
    
    logger.i('Saving ${allActiveRelayUrls.length} active relays (excluding ${blacklistedUrls.length} blacklisted) and ${userRelays.length} user relays metadata');
    
    // Save ALL active relays to settings.relays (NostrService will use these)
    await settings.updateRelays(allActiveRelayUrls);
    
    // Save user relays metadata to settings.userRelays (for persistence/reconstruction)
    final userRelaysJson = userRelays.map((r) => r.toJson()).toList();
    await settings.updateUserRelays(userRelaysJson);
    
    logger.i('Relays saved successfully');
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
      logger.i('Removed $normalizedUrl from blacklist - user manually added it');
    }

    // Step 6: Add relay as user relay
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
      // For simplicity, assume all relays are healthy in the new design
      // Health can be determined by the underlying Nostr service connection status
      updatedRelays.add(relay.copyWith(isHealthy: true));
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
          logger.e('Error handling relay list event',
              error: error, stackTrace: stackTrace);
        },
      );

      // Don't call syncWithMostroInstance() here - it's handled by Future.microtask() in constructor
      logger.i('Mostro relay sync initialized - sync will start after provider initialization');
    } catch (e, stackTrace) {
      logger.e('Failed to initialize Mostro relay sync',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Synchronize relays with the configured Mostro instance
  Future<void> syncWithMostroInstance() async {
    try {
      final mostroPubkey = settings.state.mostroPublicKey;
      if (mostroPubkey.isEmpty) {
        logger.w('No Mostro pubkey configured, skipping relay sync');
        return;
      }

      logger.i('Syncing relays with Mostro instance: $mostroPubkey');
      
      // Cancel any existing relay list subscription before creating new one
      _subscriptionManager?.unsubscribeFromMostroRelayList();
      
      // Clean existing Mostro relays from state to prevent contamination
      await _cleanMostroRelaysFromState();
      
      try {
        // Wait for NostrService to be available before subscribing
        await _waitForNostrService();
        
        // Subscribe to the new Mostro instance
        _subscriptionManager?.subscribeToMostroRelayList(mostroPubkey);
        logger.i('Successfully subscribed to relay list events for Mostro: $mostroPubkey');
        
        // Schedule a retry in case the subscription doesn't work immediately
        _scheduleRetrySync(mostroPubkey);
        
      } catch (e) {
        logger.w('Failed to subscribe immediately, will retry later: $e');
        // Schedule a retry even if initial subscription fails
        _scheduleRetrySync(mostroPubkey);
      }
    } catch (e, stackTrace) {
      logger.e('Failed to sync with Mostro instance',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Schedule a retry of the sync operation after a delay
  void _scheduleRetrySync(String mostroPubkey) {
    // Cancel any existing retry timer to prevent leaks
    _retryTimer?.cancel();
    
    _retryTimer = Timer(const Duration(seconds: 10), () async {
      try {
        if (settings.state.mostroPublicKey == mostroPubkey) {
          logger.i('Retrying relay sync for Mostro: $mostroPubkey');
          _subscriptionManager?.subscribeToMostroRelayList(mostroPubkey);
        }
      } catch (e) {
        logger.w('Retry sync failed: $e');
      } finally {
        _retryTimer = null;  // Clear reference after execution
      }
    });
  }

  /// Wait for NostrService to be initialized before proceeding
  Future<void> _waitForNostrService() async {
    const maxAttempts = 20;
    const delay = Duration(milliseconds: 500);
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final nostrService = ref.read(nostrServiceProvider);
        // Check if NostrService is actually initialized
        if (nostrService.isInitialized) {
          logger.i('NostrService is ready for relay subscriptions');
          return;
        }
      } catch (e) {
        logger.w('NostrService not accessible yet, attempt ${attempt + 1}/$maxAttempts: $e');
      }
      
      if (attempt < maxAttempts - 1) {
        await Future.delayed(delay);
      }
    }
    
    logger.e('NostrService failed to initialize after $maxAttempts attempts');
    throw Exception('NostrService not available for relay synchronization');
  }

  /// Handle relay list updates from Mostro instance
  Future<void> _handleMostroRelayListUpdate(RelayListEvent event) async {
    try {
      final currentMostroPubkey = settings.state.mostroPublicKey;
      
      // Validate that this event is from the currently configured Mostro instance
      if (event.authorPubkey != currentMostroPubkey) {
        logger.w('Ignoring relay list event from wrong Mostro instance. '
            'Expected: $currentMostroPubkey, Got: ${event.authorPubkey}');
        return;
      }
      
      // Timestamp validation: ignore events older than the last processed event
      if (_lastProcessedEventTime != null && 
          event.publishedAt.isBefore(_lastProcessedEventTime!)) {
        logger.i('Ignoring older relay list event from ${event.publishedAt} '
            '(last processed: $_lastProcessedEventTime)');
        return;
      }
      
      // Hash-based deduplication: ignore identical relay lists
      final relayListHash = event.validRelays.join(',');
      if (_lastRelayListHash == relayListHash) {
        logger.i('Relay list unchanged (hash match), skipping update');
        return;
      }
      
      logger.i('Received relay list from Mostro ${event.authorPubkey}: ${event.relays}');
      
      // Normalize relay URLs to prevent duplicates
      final normalizedRelays = event.validRelays
          .map((url) => _normalizeRelayUrl(url))
          .whereType<String>()  // Filter out any null results
          .toSet() // Remove duplicates
          .toList();
      
      // Get blacklisted relays from settings and normalize them for consistent matching
      final blacklistedUrls = settings.state.blacklistedRelays
          .map((url) => _normalizeRelayUrl(url))
          .whereType<String>()  // Filter out any null results
          .toSet();

      // Start with user relays (they stay at the end and are never affected by Mostro sync)
      final userRelays = state.where((relay) => relay.source == RelaySource.user).toList();
      
      // Keep default relays ONLY if they are not blacklisted
      final updatedRelays = state
          .where((relay) => relay.source == RelaySource.defaultConfig && !blacklistedUrls.contains(_normalizeRelayUrl(relay.url)))
          .toList();
      
      logger.i('Kept ${updatedRelays.length} default relays and ${userRelays.length} user relays');
      
      // Process Mostro relays from 10002 event
      for (final relayUrl in normalizedRelays) {
        // Skip if blacklisted by user
        if (blacklistedUrls.contains(relayUrl)) {
          logger.i('Skipping blacklisted Mostro relay: $relayUrl');
          continue;
        }

        // Check if this relay was previously a user relay (PROMOTION case)
        final existingUserRelay = userRelays.firstWhere(
          (r) => _normalizeRelayUrl(r.url) == relayUrl, 
          orElse: () => Relay(url: ''), // Empty relay if not found
        );
        
        if (existingUserRelay.url.isNotEmpty) {
          // PROMOTION: User relay → Mostro relay (move to beginning)
          userRelays.removeWhere((r) => _normalizeRelayUrl(r.url) == relayUrl);
          final promotedRelay = Relay.fromMostro(relayUrl);
          updatedRelays.insert(0, promotedRelay); // Insert at beginning
          logger.i('Promoted user relay to Mostro relay: $relayUrl');
          continue;
        }

        // Skip if already in updatedRelays (avoid duplicates with default relays)
        if (updatedRelays.any((r) => _normalizeRelayUrl(r.url) == relayUrl)) {
          logger.i('Skipping duplicate relay: $relayUrl');
          continue;
        }
        
        // Add new Mostro relay
        final mostroRelay = Relay.fromMostro(relayUrl);
        updatedRelays.add(mostroRelay);
        logger.i('Added Mostro relay: $relayUrl');
      }

      // Remove Mostro relays that are no longer in the 10002 event (ELIMINATION case)
      final currentMostroRelays = state.where((relay) => relay.source == RelaySource.mostro).toList();
      for (final mostroRelay in currentMostroRelays) {
        if (!normalizedRelays.contains(_normalizeRelayUrl(mostroRelay.url))) {
          logger.i('Removing Mostro relay no longer in 10002: ${mostroRelay.url}');
          // Relay is eliminated completely - no reverting to user relay
        }
      }

      // Final relay order: [Default relays...] [Mostro relays...] [User relays...]
      final finalRelays = [...updatedRelays, ...userRelays];

      // Update state if there are changes
      if (finalRelays.length != state.length || 
          !finalRelays.every((relay) => state.contains(relay))) {
        state = finalRelays;
        await _saveRelays();
        logger.i('Updated relay list with ${finalRelays.length} relays (${blacklistedUrls.length} blacklisted)');
      }
      
      // Update tracking variables after successful processing
      _lastProcessedEventTime = event.publishedAt;
      _lastRelayListHash = relayListHash;
    } catch (e, stackTrace) {
      logger.e('Error handling Mostro relay list update',
          error: e, stackTrace: stackTrace);
    }
  }


  /// Remove relay with blacklist support
  /// All relays are now blacklisted when removed (since no user relays exist)
  Future<void> removeRelayWithBlacklist(String url) async {
    final relay = state.firstWhere((r) => r.url == url, orElse: () => Relay(url: ''));
    
    if (relay.url.isEmpty) {
      logger.w('Attempted to remove non-existent relay: $url');
      return;
    }

    // Blacklist all relays to prevent re-addition during sync
    await settings.addToBlacklist(url);
    logger.i('Blacklisted ${relay.source} relay: $url');

    // Remove relay from current state
    await removeRelay(url);
    logger.i('Removed relay: $url (source: ${relay.source})');
  }

  // Removed removeRelayWithSource - no longer needed since all relays are managed via blacklist

  /// Initialize settings listener to watch for Mostro pubkey changes
  void _initSettingsListener() {
    // Watch settings changes and re-sync when Mostro pubkey changes
    String? currentPubkey = settings.state.mostroPublicKey;
    
    // Use a simple timer to periodically check for changes
    // This avoids circular dependency issues with provider watching
    _settingsWatchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final newPubkey = settings.state.mostroPublicKey;
      
      // Only reset if there's a REAL change (both values are non-empty and different)
      if (newPubkey != currentPubkey && 
          currentPubkey != null && 
          newPubkey.isNotEmpty && 
          currentPubkey!.isNotEmpty) {
        logger.i('Detected REAL Mostro pubkey change: $currentPubkey -> $newPubkey');
        currentPubkey = newPubkey;
        
        // 🔥 RESET COMPLETO: Limpiar todos los relays y hacer sync fresco
        _cleanAllRelaysAndResync();
      } else if (newPubkey != currentPubkey) {
        // Just update the tracking variable without reset (initial load)
        logger.i('Initial Mostro pubkey load: $newPubkey');
        currentPubkey = newPubkey;
        syncWithMostroInstance();
      }
    });
  }

  /// Clean all relays (except default) and perform fresh sync with new Mostro
  Future<void> _cleanAllRelaysAndResync() async {
    try {
      logger.i('Cleaning all relays and performing fresh sync...');
      
      // CLEAR ALL relays (only keep default)
      final defaultRelay = Relay.fromDefault('wss://relay.mostro.network');
      state = [defaultRelay];
      await _saveRelays();
      
      logger.i('Reset to default relay only, starting fresh sync');
      
      // Reset hash and timestamp for completely fresh sync with new Mostro
      _lastRelayListHash = null;
      _lastProcessedEventTime = null;
      
      // Start completely fresh sync with new Mostro
      await syncWithMostroInstance();
      
    } catch (e, stackTrace) {
      logger.e('Error during relay cleanup and resync',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Check if a relay URL is currently blacklisted
  bool isRelayBlacklisted(String url) {
    return settings.state.blacklistedRelays.contains(url);
  }

  /// Get all blacklisted relay URLs
  List<String> get blacklistedRelays => settings.blacklistedRelays;

  /// Get all relays (Mostro, default, and user relays) with their status
  /// This is used for the settings UI to show all relays with their status
  /// Order: [Default relays...] [Mostro relays...] [User relays...]
  List<MostroRelayInfo> get mostroRelaysWithStatus {
    final blacklistedUrls = settings.state.blacklistedRelays;
    final activeRelays = state.map((r) => r.url).toSet();
    final allRelayInfos = <MostroRelayInfo>[];
    
    // 1. Get active Mostro and default relays
    final mostroAndDefaultActiveRelays = state
        .where((r) => r.source == RelaySource.mostro || r.source == RelaySource.defaultConfig)
        .map((r) => MostroRelayInfo(
              url: r.url,
              // Check if this relay is blacklisted (even if it's still in state)
              isActive: !blacklistedUrls.contains(r.url),
              isHealthy: r.isHealthy,
              source: r.source,
            ))
        .toList();
    
    // 2. Add blacklisted Mostro/default relays that are NOT in the active state
    final mostroBlacklistedRelays = blacklistedUrls
        .where((url) => !activeRelays.contains(url))
        .map((url) => MostroRelayInfo(
              url: url,
              isActive: false,
              isHealthy: false,
              source: null, // Unknown source for blacklisted-only relays
            ))
        .toList();
    
    // 3. Combine Mostro/default relays and sort alphabetically
    final allMostroDefaultRelays = [...mostroAndDefaultActiveRelays, ...mostroBlacklistedRelays];
    allMostroDefaultRelays.sort((a, b) => a.url.compareTo(b.url));
    allRelayInfos.addAll(allMostroDefaultRelays);
    
    // 4. Get user relays (always at the end)
    final userRelays = state
        .where((r) => r.source == RelaySource.user)
        .map((r) => MostroRelayInfo(
              url: r.url,
              isActive: !blacklistedUrls.contains(r.url), // User relays can also be blacklisted
              isHealthy: r.isHealthy,
              source: r.source,
            ))
        .toList();
    
    // Sort user relays alphabetically and add to end
    userRelays.sort((a, b) => a.url.compareTo(b.url));
    allRelayInfos.addAll(userRelays);
    
    return allRelayInfos;
  }

  /// Check if blacklisting this relay would leave the app without any active relays
  bool wouldLeaveNoActiveRelays(String urlToBlacklist) {
    final currentActiveRelays = state.map((r) => r.url).toList();
    final currentBlacklist = settings.state.blacklistedRelays;
    
    // Simulate what would happen if we blacklist this URL
    final wouldBeBlacklisted = [...currentBlacklist, urlToBlacklist];
    final wouldRemainActive = currentActiveRelays.where((url) => !wouldBeBlacklisted.contains(url)).toList();
    
    logger.d('Current active: ${currentActiveRelays.length}, Would remain: ${wouldRemainActive.length}');
    return wouldRemainActive.isEmpty;
  }

  /// Toggle blacklist status for a Mostro relay
  /// If active -> blacklist it and remove from active relays  
  /// If blacklisted -> remove from blacklist and trigger re-sync to add back
  Future<void> toggleMostroRelayBlacklist(String url) async {
    final isCurrentlyBlacklisted = settings.state.blacklistedRelays.contains(url);
    
    if (isCurrentlyBlacklisted) {
      // Remove from blacklist and trigger sync to add back
      await settings.removeFromBlacklist(url);
      logger.i('Removed $url from blacklist, triggering re-sync');
      
      // Reset hash to allow re-processing of the same relay list with updated blacklist context
      _lastRelayListHash = null;
      
      await syncWithMostroInstance();
    } else {
      // Add to blacklist and remove from current state
      await settings.addToBlacklist(url);
      await removeRelay(url);
      logger.i('Blacklisted and removed Mostro relay: $url');
    }
  }

  /// Clear all blacklisted relays and trigger re-sync
  Future<void> clearBlacklistAndResync() async {
    await settings.clearBlacklist();
    logger.i('Cleared blacklist, triggering relay re-sync');
    
    // Reset hash to allow re-processing of relay lists with cleared blacklist
    _lastRelayListHash = null;
    
    await syncWithMostroInstance();
  }

  /// Clean existing Mostro relays from state when switching instances
  Future<void> _cleanMostroRelaysFromState() async {
    // Get blacklisted relays for filtering
    final blacklistedUrls = settings.state.blacklistedRelays
        .map((url) => _normalizeRelayUrl(url))
        .toSet();
    
    // Keep default config relays, user relays, AND non-blacklisted Mostro relays
    final cleanedRelays = state.where((relay) => 
        relay.source == RelaySource.defaultConfig || 
        relay.source == RelaySource.user ||
        (relay.source == RelaySource.mostro && !blacklistedUrls.contains(_normalizeRelayUrl(relay.url)))
    ).toList();
    if (cleanedRelays.length != state.length) {
      final removedCount = state.length - cleanedRelays.length;
      state = cleanedRelays;
      await _saveRelays();
      logger.i('Cleaned $removedCount Mostro relays from state');
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
    _retryTimer?.cancel();  // Cancel retry timer to prevent leak
    super.dispose();
  }
}
