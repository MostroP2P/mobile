import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';

/// Enhanced connection manager with exponential backoff and fault tolerance
class ConnectionManager extends StateNotifier<ConnectionState> {
  final Ref ref;
  final Logger _logger = Logger();
  DateTime? _lastConnectionAttempt;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  
  // Network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasNetworkConnection = true;
  
  // Configuration
  static const int maxReconnectAttempts = 10;
  static const Duration baseRetryDelay = Duration(seconds: 1);
  static const Duration maxRetryDelay = Duration(minutes: 5);
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
  
  // State streams
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _errorController = StreamController<ConnectionError>.broadcast();
  
  Stream<ConnectionState> get connectionState => _stateController.stream;
  Stream<ConnectionError> get connectionErrors => _errorController.stream;
  
  ConnectionState get currentState => state;
  bool get isConnected => state == ConnectionState.connected;
  bool get isConnecting => state == ConnectionState.connecting;
  bool get isReconnecting => state == ConnectionState.reconnecting;
  
  ConnectionManager(this.ref) : super(ConnectionState.disconnected) {
    _initializeConnectionMonitoring();
  }
  
  /// Initialize monitoring of actual NostrService connection state
  void _initializeConnectionMonitoring() {
    // Check current NostrService state and sync our state
    _syncWithNostrService();
    
    // Start system-level network monitoring
    _startNetworkMonitoring();
    
    // Start periodic health checks to monitor connection
    _startHealthCheck();
  }
  
  /// Start monitoring system-level network connectivity
  void _startNetworkMonitoring() {
    _logger.i('Starting system-level network monitoring');
    
    // Get initial connectivity state
    Connectivity().checkConnectivity().then((result) {
      _onConnectivityChanged(result);
    }).catchError((error) {
      _logger.w('Failed to check initial connectivity: $error');
    });
    
    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        _logger.e('Connectivity monitoring error: $error');
      },
    );
  }
  
  /// Handle connectivity changes from system
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final wasConnected = _hasNetworkConnection;
    
    // Determine if we have any network connection
    _hasNetworkConnection = result.any((connectivity) => 
      connectivity != ConnectivityResult.none
    );
    
    _logger.i('Network connectivity changed: $result (hasConnection: $_hasNetworkConnection)');
    
    if (!wasConnected && _hasNetworkConnection) {
      // Network came back online
      _logger.i('Network connection restored - attempting reconnect');
      _onNetworkRestored();
    } else if (wasConnected && !_hasNetworkConnection) {
      // Network went offline
      _logger.w('Network connection lost');
      _onNetworkLost();
    }
  }
  
  /// Handle network restoration
  void _onNetworkRestored() {
    // Cancel any existing reconnect timers
    _cancelReconnectTimer();
    
    // If we were disconnected or reconnecting, try to reconnect immediately
    if (state == ConnectionState.disconnected || state == ConnectionState.reconnecting) {
      _logger.i('Network restored - initiating immediate reconnection');
      
      // Reset reconnect attempts for network restoration
      _reconnectAttempts = 0;
      
      // Attempt reconnection with current settings
      _attemptReconnectWithSettings();
    }
  }
  
  /// Handle network loss
  void _onNetworkLost() {
    if (state != ConnectionState.disconnected) {
      _logger.w('Network lost while connected ($state), disconnecting');
      _setState(ConnectionState.disconnected);
      
      // Don't immediately start reconnecting when network is unavailable
      _cancelReconnectTimer();
    }
  }
  
  /// Attempt reconnect with current settings
  void _attemptReconnectWithSettings() {
    try {
      final settings = ref.read(settingsProvider);
      connect(settings);
    } catch (e) {
      _logger.e('Failed to get settings for reconnection: $e');
      _scheduleReconnect();
    }
  }
  
  /// Sync ConnectionManager state with actual NostrService state
  void _syncWithNostrService() {
    try {
      final nostrService = ref.read(nostrServiceProvider);
      
      if (nostrService.isInitialized) {
        // NostrService is connected, update our state
        if (state != ConnectionState.connected) {
          _logger.i('Syncing with NostrService: Connected');
          _setState(ConnectionState.connected);
          _reconnectAttempts = 0;
        }
      } else {
        // NostrService is not connected, update our state
        if (state == ConnectionState.connected) {
          _logger.i('Syncing with NostrService: Disconnected');
          _setState(ConnectionState.disconnected);
        }
      }
    } catch (e) {
      _logger.w('Error syncing with NostrService: $e');
      if (state == ConnectionState.connected) {
        _setState(ConnectionState.disconnected);
      }
    }
  }
  
  /// Calculate exponential backoff delay with jitter
  Duration _calculateBackoffDelay() {
    if (_reconnectAttempts == 0) return baseRetryDelay;
    
    // Exponential backoff: base * 2^attempts
    final exponentialDelay = baseRetryDelay * pow(2, _reconnectAttempts);
    final cappedDelay = exponentialDelay > maxRetryDelay ? maxRetryDelay : exponentialDelay;
    
    // Add jitter (±25% random variation)
    final jitter = cappedDelay * (0.75 + (Random().nextDouble() * 0.5));
    
    _logger.d('Backoff delay for attempt $_reconnectAttempts: ${jitter.inSeconds}s');
    return jitter;
  }
  
  /// Start connection with retry logic
  Future<void> connect(Settings settings) async {
    if (state == ConnectionState.connecting || state == ConnectionState.reconnecting) {
      _logger.w('Connection already in progress, ignoring connect request');
      return;
    }
    
    _setState(ConnectionState.connecting);
    _lastConnectionAttempt = DateTime.now();
    
    try {
      await _attemptConnection(settings);
      _onConnectionSuccess();
    } catch (e) {
      _onConnectionFailure(e);
    }
  }
  
  /// Attempt actual connection
  Future<void> _attemptConnection(Settings settings) async {
    _logger.i('Attempting connection to relays: ${settings.relays}');
    
    // Validate settings
    if (settings.relays.isEmpty) {
      throw ConnectionException('No relays configured');
    }
    
    // Integrate with actual NostrService connection logic
    final nostrService = ref.read(nostrServiceProvider);
    
    try {
      // Initialize connection with timeout
      await nostrService.init(settings).timeout(connectionTimeout);
      
      // Verify connection is actually established by checking if service is initialized
      if (!nostrService.isInitialized) {
        throw ConnectionException('NostrService initialization failed');
      }
      
      _logger.i('Successfully connected to ${settings.relays.length} relays');
    } catch (e) {
      throw ConnectionException('Failed to connect to Nostr relays: $e');
    }
  }
  
  /// Handle successful connection
  void _onConnectionSuccess() {
    _logger.i('Connection established successfully');
    _reconnectAttempts = 0;
    _setState(ConnectionState.connected);
    _startHealthCheck();
    _cancelReconnectTimer();
    
    // Trigger subscription restoration after successful connection
    _restoreSubscriptions();
  }
  
  /// Restore all active subscriptions after reconnection
  void _restoreSubscriptions() {
    try {
      _logger.i('Restoring subscriptions after reconnection');
      
      // Get the subscription manager and force resubscription
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      
      // Force complete subscription refresh - this will unsubscribe all current
      // subscriptions and resubscribe based on current sessions
      subscriptionManager.subscribeAll();
      
      _logger.i('All subscriptions restored successfully');
    } catch (e) {
      _logger.e('Failed to restore subscriptions: $e');
      // Don't fail the connection for subscription issues
    }
  }
  
  /// Handle connection failure
  void _onConnectionFailure(dynamic error) {
    _logger.e('Connection failed: $error');
    
    final connectionError = ConnectionError(
      message: error.toString(),
      timestamp: DateTime.now(),
      attemptNumber: _reconnectAttempts + 1,
    );
    _errorController.add(connectionError);
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      _logger.e('Max reconnection attempts reached, giving up');
      _setState(ConnectionState.failed);
    }
  }
  
  /// Schedule reconnection with backoff
  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay = _calculateBackoffDelay();
    
    _logger.i('Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _setState(ConnectionState.reconnecting);
    
    _reconnectTimer = Timer(delay, () {
      if (state == ConnectionState.reconnecting) {
        // Get current settings and retry
        final settings = ref.read(settingsProvider);
        connect(settings).catchError((e) {
          _logger.e('Scheduled reconnect failed: $e');
          _onConnectionFailure(e);
        });
      }
    });
  }
  
  /// Start periodic health checks
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }
  
  /// Perform connection health check
  void _performHealthCheck() async {
    _logger.d('Performing connection health check');
    
    try {
      // First check network connectivity - this is critical!
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _logger.w('Health check failed: No network connectivity');
        _onNetworkLost();
        return;
      }
      
      // Then sync with NostrService state
      _syncWithNostrService();
      
      // Check if NostrService is still initialized and functional
      final nostrService = ref.read(nostrServiceProvider);
      if (!nostrService.isInitialized) {
        _logger.w('Health check failed: NostrService not initialized');
        onConnectionLost('NostrService lost initialization');
        return;
      }
      
      // Additional health checks could include:
      // - Verify relay connections are still active
      // - Check subscription status
      // - Send test message if needed
      
      _logger.d('Connection health check passed');
    } catch (e) {
      _logger.w('Health check failed: $e');
      onConnectionLost('Health check failure: $e');
    }
  }
  
  /// Handle connection loss
  void onConnectionLost(dynamic error) {
    if (state == ConnectionState.connected) {
      _logger.w('Connection lost: $error');
      _setState(ConnectionState.reconnecting);
      _scheduleReconnect();
    }
  }
  
  /// Force reconnect (manual retry)
  Future<void> reconnect() async {
    _logger.i('Manual reconnect requested');
    _cancelReconnectTimer();
    _reconnectAttempts = 0; // Reset attempts for manual reconnect
    
    // Get settings from provider and attempt connection
    try {
      final settings = ref.read(settingsProvider);
      await connect(settings);
    } catch (e) {
      _logger.e('Manual reconnect failed: $e');
      _setState(ConnectionState.failed);
    }
  }
  
  /// Force disconnect
  void disconnect() {
    _logger.i('Disconnecting from relays');
    _setState(ConnectionState.disconnected);
    _cancelReconnectTimer();
    _healthCheckTimer?.cancel();
    _reconnectAttempts = 0;
  }
  
  /// Update connection state
  void _setState(ConnectionState newState) {
    if (state != newState) {
      _logger.d('Connection state: $state -> $newState');
      state = newState;
      _stateController.add(newState);
    }
  }
  
  /// Cancel reconnect timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  /// Get connection statistics
  ConnectionStats getStats() {
    return ConnectionStats(
      currentState: state,
      reconnectAttempts: _reconnectAttempts,
      lastConnectionAttempt: _lastConnectionAttempt,
      uptime: state == ConnectionState.connected 
          ? DateTime.now().difference(_lastConnectionAttempt ?? DateTime.now())
          : null,
    );
  }
  
  @override
  void dispose() {
    _cancelReconnectTimer();
    _healthCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _stateController.close();
    _errorController.close();
    super.dispose();
  }
}

/// Connection states
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Connection error information
class ConnectionError {
  final String message;
  final DateTime timestamp;
  final int attemptNumber;
  
  ConnectionError({
    required this.message,
    required this.timestamp,
    required this.attemptNumber,
  });
}

/// Connection exception for connection-related errors
class ConnectionException implements Exception {
  final String message;
  
  ConnectionException(this.message);
  
  @override
  String toString() => 'ConnectionException: $message';
}

/// Connection statistics
class ConnectionStats {
  final ConnectionState currentState;
  final int reconnectAttempts;
  final DateTime? lastConnectionAttempt;
  final Duration? uptime;
  
  ConnectionStats({
    required this.currentState,
    required this.reconnectAttempts,
    this.lastConnectionAttempt,
    this.uptime,
  });
}



/// Provider for connection manager
final connectionManagerProvider = StateNotifierProvider<ConnectionManager, ConnectionState>((ref) => ConnectionManager(ref));

/// Provider for connection manager instance (for accessing methods)
final connectionManagerInstanceProvider = Provider<ConnectionManager>((ref) => ref.read(connectionManagerProvider.notifier));
