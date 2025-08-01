import 'dart:async';
import 'dart:io';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
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

  RelaysNotifier(this.settings) : super([]) {
    _loadRelays();
  }

  void _loadRelays() {
    final saved = settings.state;
    state = saved.relays.map((url) => Relay(url: url)).toList();
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
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    );
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
      // Create a temporary Nostr instance for testing
      final testNostr = Nostr.instance;
      
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
    
    // Step 5: Add relay only if it's healthy (responds to Nostr protocol)
    final newRelay = Relay(url: normalizedUrl, isHealthy: true);
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
}
