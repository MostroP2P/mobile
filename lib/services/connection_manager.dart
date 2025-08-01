import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Enhanced connection manager with exponential backoff and fault tolerance
class ConnectionManager {
  final Ref ref;
  final Logger _logger = Logger();
  
  // Connection state
  ConnectionState _state = ConnectionState.disconnected;
  DateTime? _lastConnectionAttempt;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  
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
  
  ConnectionState get currentState => _state;
  bool get isConnected => _state == ConnectionState.connected;
  bool get isConnecting => _state == ConnectionState.connecting;
  bool get isReconnecting => _state == ConnectionState.reconnecting;
  
  ConnectionManager(this.ref);
  
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
    if (_state == ConnectionState.connecting || _state == ConnectionState.reconnecting) {
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
      if (_state == ConnectionState.reconnecting) {
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
  void _performHealthCheck() {
    if (_state != ConnectionState.connected) return;
    
    // Implement actual health check
    try {
      final nostrService = ref.read(nostrServiceProvider);
      
      // Check if NostrService is still initialized and functional
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
    if (_state == ConnectionState.connected) {
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
    if (_state != newState) {
      _logger.d('Connection state: $_state -> $newState');
      _state = newState;
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
      currentState: _state,
      reconnectAttempts: _reconnectAttempts,
      lastConnectionAttempt: _lastConnectionAttempt,
      uptime: _state == ConnectionState.connected 
          ? DateTime.now().difference(_lastConnectionAttempt ?? DateTime.now())
          : null,
    );
  }
  
  void dispose() {
    _cancelReconnectTimer();
    _healthCheckTimer?.cancel();
    _stateController.close();
    _errorController.close();
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
final connectionManagerProvider = Provider((ref) => ConnectionManager(ref));
