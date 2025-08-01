import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/services/connection_manager.dart';

/// Comprehensive diagnostics and metrics for relay connections
class RelayDiagnostics {
  final Ref ref;
  final Logger _logger = Logger();
  
  // Metrics tracking
  final Map<String, int> _eventCounts = {};
  final Map<String, Duration> _responseTimes = {};
  final List<ConnectionEvent> _connectionHistory = [];
  final List<MessageEvent> _messageHistory = [];
  final Map<String, int> _errorCounts = {};
  
  // Performance tracking
  DateTime? _lastHealthCheck;
  final Map<String, DateTime> _subscriptionStartTimes = {};
  final Map<String, int> _subscriptionEventCounts = {};
  
  // Configuration
  static const int maxHistoryEntries = 1000;
  static const Duration metricsRetentionPeriod = Duration(hours: 24);
  
  RelayDiagnostics(this.ref) {
    _startMetricsCollection();
  }
  
  /// Start collecting metrics
  void _startMetricsCollection() {
    // Listen to connection state changes
    ref.read(connectionManagerProvider).connectionState.listen((state) {
      _recordConnectionEvent(state);
    });
    
    // Listen to connection errors
    ref.read(connectionManagerProvider).connectionErrors.listen((error) {
      _recordConnectionError(error);
    });
    
    // Start periodic cleanup
    Timer.periodic(const Duration(hours: 1), (_) => _cleanupOldMetrics());
  }
  
  /// Record connection state change
  void _recordConnectionEvent(ConnectionState state) {
    final event = ConnectionEvent(
      state: state,
      timestamp: DateTime.now(),
      relayUrl: 'wss://relay.mostro.network', // TODO: Get from settings
    );
    
    _connectionHistory.add(event);
    _trimHistory(_connectionHistory);
    
    _logger.i('Connection event recorded: $state');
  }
  
  /// Record connection error
  void _recordConnectionError(ConnectionError error) {
    final errorKey = 'connection_error';
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    
    _logger.w('Connection error recorded: ${error.message}');
  }
  
  /// Record message sent
  void recordMessageSent(Action action, String orderId, {Duration? responseTime}) {
    final event = MessageEvent(
      type: MessageType.sent,
      action: action,
      orderId: orderId,
      timestamp: DateTime.now(),
      responseTime: responseTime,
    );
    
    _messageHistory.add(event);
    _trimHistory(_messageHistory);
    
    // Update counters
    final key = 'sent_${action.name}';
    _eventCounts[key] = (_eventCounts[key] ?? 0) + 1;
    
    if (responseTime != null) {
      _responseTimes[key] = responseTime;
    }
    
    _logger.d('Message sent recorded: $action for order $orderId');
  }
  
  /// Record message received
  void recordMessageReceived(Action action, String orderId) {
    final event = MessageEvent(
      type: MessageType.received,
      action: action,
      orderId: orderId,
      timestamp: DateTime.now(),
    );
    
    _messageHistory.add(event);
    _trimHistory(_messageHistory);
    
    // Update counters
    final key = 'received_${action.name}';
    _eventCounts[key] = (_eventCounts[key] ?? 0) + 1;
    
    _logger.d('Message received recorded: $action for order $orderId');
  }
  
  /// Record subscription start
  void recordSubscriptionStart(String subscriptionId, String filterDescription) {
    _subscriptionStartTimes[subscriptionId] = DateTime.now();
    _subscriptionEventCounts[subscriptionId] = 0;
    
    _logger.i('Subscription started: $subscriptionId ($filterDescription)');
  }
  
  /// Record subscription event
  void recordSubscriptionEvent(String subscriptionId) {
    _subscriptionEventCounts[subscriptionId] = 
        (_subscriptionEventCounts[subscriptionId] ?? 0) + 1;
  }
  
  /// Record subscription end
  void recordSubscriptionEnd(String subscriptionId) {
    final startTime = _subscriptionStartTimes.remove(subscriptionId);
    final eventCount = _subscriptionEventCounts.remove(subscriptionId) ?? 0;
    
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _logger.i('Subscription ended: $subscriptionId (${duration.inMinutes}min, $eventCount events)');
    }
  }
  
  /// Record error
  void recordError(String errorType, String description) {
    _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
    _logger.e('Error recorded: $errorType - $description');
  }
  
  /// Record health check
  void recordHealthCheck(bool success, Duration responseTime) {
    _lastHealthCheck = DateTime.now();
    
    final key = success ? 'health_check_success' : 'health_check_failure';
    _eventCounts[key] = (_eventCounts[key] ?? 0) + 1;
    
    if (success) {
      _responseTimes['health_check'] = responseTime;
    }
    
    _logger.d('Health check recorded: success=$success, time=${responseTime.inMilliseconds}ms');
  }
  
  /// Get comprehensive diagnostics report
  DiagnosticsReport generateReport() {
    final now = DateTime.now();
    
    return DiagnosticsReport(
      timestamp: now,
      connectionStats: _generateConnectionStats(),
      messageStats: _generateMessageStats(),
      subscriptionStats: _generateSubscriptionStats(),
      errorStats: Map.from(_errorCounts),
      performanceStats: _generatePerformanceStats(),
      healthStatus: _generateHealthStatus(),
    );
  }
  
  /// Generate connection statistics
  ConnectionStats _generateConnectionStats() {
    final recentConnections = _connectionHistory
        .where((e) => DateTime.now().difference(e.timestamp) < const Duration(hours: 1))
        .toList();
    
    final connectionsByState = <ConnectionState, int>{};
    for (final event in recentConnections) {
      connectionsByState[event.state] = (connectionsByState[event.state] ?? 0) + 1;
    }
    
    final currentState = ref.read(connectionManagerProvider).currentState;
    final uptime = _calculateUptime();
    
    return ConnectionStats(
      currentState: currentState,
      recentStateChanges: connectionsByState,
      uptime: uptime,
      totalReconnects: connectionsByState[ConnectionState.reconnecting] ?? 0,
    );
  }
  
  /// Generate message statistics
  MessageStats _generateMessageStats() {
    final recentMessages = _messageHistory
        .where((e) => DateTime.now().difference(e.timestamp) < const Duration(hours: 1))
        .toList();
    
    final sentCount = recentMessages.where((m) => m.type == MessageType.sent).length;
    final receivedCount = recentMessages.where((m) => m.type == MessageType.received).length;
    
    final avgResponseTime = _calculateAverageResponseTime();
    
    return MessageStats(
      messagesSent: sentCount,
      messagesReceived: receivedCount,
      averageResponseTime: avgResponseTime,
      messagesByAction: _groupMessagesByAction(recentMessages),
    );
  }
  
  /// Generate subscription statistics
  SubscriptionStats _generateSubscriptionStats() {
    final activeSubscriptions = _subscriptionStartTimes.length;
    final totalEvents = _subscriptionEventCounts.values.fold(0, (a, b) => a + b);
    
    return SubscriptionStats(
      activeSubscriptions: activeSubscriptions,
      totalEventsReceived: totalEvents,
      subscriptionDetails: Map.from(_subscriptionEventCounts),
    );
  }
  
  /// Generate performance statistics
  PerformanceStats _generatePerformanceStats() {
    final avgResponseTimes = <String, Duration>{};
    for (final entry in _responseTimes.entries) {
      avgResponseTimes[entry.key] = entry.value;
    }
    
    return PerformanceStats(
      averageResponseTimes: avgResponseTimes,
      lastHealthCheck: _lastHealthCheck,
      memoryUsage: _estimateMemoryUsage(),
    );
  }
  
  /// Generate health status
  HealthStatus _generateHealthStatus() {
    final isConnected = ref.read(connectionManagerProvider).isConnected;
    final recentErrors = _errorCounts.values.fold(0, (a, b) => a + b);
    final lastHealthCheck = _lastHealthCheck;
    
    String status;
    if (!isConnected) {
      status = 'disconnected';
    } else if (recentErrors > 10) {
      status = 'degraded';
    } else if (lastHealthCheck != null && 
               DateTime.now().difference(lastHealthCheck) > const Duration(minutes: 5)) {
      status = 'unknown';
    } else {
      status = 'healthy';
    }
    
    return HealthStatus(
      status: status,
      lastHealthCheck: lastHealthCheck,
      recentErrorCount: recentErrors,
      issues: _identifyIssues(),
    );
  }
  
  /// Calculate uptime
  Duration? _calculateUptime() {
    final connectedEvents = _connectionHistory
        .where((e) => e.state == ConnectionState.connected)
        .toList();
    
    if (connectedEvents.isEmpty) return null;
    
    final lastConnected = connectedEvents.last.timestamp;
    return DateTime.now().difference(lastConnected);
  }
  
  /// Calculate average response time
  Duration? _calculateAverageResponseTime() {
    if (_responseTimes.isEmpty) return null;
    
    final totalMs = _responseTimes.values
        .map((d) => d.inMilliseconds)
        .fold(0, (a, b) => a + b);
    
    return Duration(milliseconds: totalMs ~/ _responseTimes.length);
  }
  
  /// Group messages by action
  Map<String, int> _groupMessagesByAction(List<MessageEvent> messages) {
    final grouped = <String, int>{};
    for (final message in messages) {
      final key = message.action.name;
      grouped[key] = (grouped[key] ?? 0) + 1;
    }
    return grouped;
  }
  
  /// Estimate memory usage
  int _estimateMemoryUsage() {
    // Rough estimate based on stored data
    final historySize = (_connectionHistory.length + _messageHistory.length) * 100; // bytes per event
    final countersSize = (_eventCounts.length + _errorCounts.length) * 50; // bytes per counter
    return historySize + countersSize;
  }
  
  /// Identify potential issues
  List<String> _identifyIssues() {
    final issues = <String>[];
    
    // Check for frequent reconnections
    final recentReconnects = _connectionHistory
        .where((e) => e.state == ConnectionState.reconnecting &&
                     DateTime.now().difference(e.timestamp) < const Duration(hours: 1))
        .length;
    
    if (recentReconnects > 5) {
      issues.add('Frequent reconnections detected ($recentReconnects in last hour)');
    }
    
    // Check for high error rate
    final recentErrors = _errorCounts.values.fold(0, (a, b) => a + b);
    if (recentErrors > 20) {
      issues.add('High error rate detected ($recentErrors recent errors)');
    }
    
    // Check for slow responses
    final avgResponseTime = _calculateAverageResponseTime();
    if (avgResponseTime != null && avgResponseTime > const Duration(seconds: 5)) {
      issues.add('Slow response times detected (avg: ${avgResponseTime.inSeconds}s)');
    }
    
    return issues;
  }
  
  /// Trim history to prevent memory leaks
  void _trimHistory<T>(List<T> history) {
    if (history.length > maxHistoryEntries) {
      history.removeRange(0, history.length - maxHistoryEntries);
    }
  }
  
  /// Clean up old metrics
  void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(metricsRetentionPeriod);
    
    _connectionHistory.removeWhere((e) => e.timestamp.isBefore(cutoff));
    _messageHistory.removeWhere((e) => e.timestamp.isBefore(cutoff));
    
    _logger.d('Cleaned up old metrics');
  }
  
  /// Export diagnostics as JSON
  String exportDiagnostics() {
    final report = generateReport();
    return jsonEncode(report.toJson());
  }
  
  void dispose() {
    _connectionHistory.clear();
    _messageHistory.clear();
    _eventCounts.clear();
    _responseTimes.clear();
    _errorCounts.clear();
  }
}

/// Connection event
class ConnectionEvent {
  final ConnectionState state;
  final DateTime timestamp;
  final String relayUrl;
  
  ConnectionEvent({
    required this.state,
    required this.timestamp,
    required this.relayUrl,
  });
}

/// Message event
class MessageEvent {
  final MessageType type;
  final Action action;
  final String orderId;
  final DateTime timestamp;
  final Duration? responseTime;
  
  MessageEvent({
    required this.type,
    required this.action,
    required this.orderId,
    required this.timestamp,
    this.responseTime,
  });
}

/// Message type
enum MessageType { sent, received }

/// Diagnostics report
class DiagnosticsReport {
  final DateTime timestamp;
  final ConnectionStats connectionStats;
  final MessageStats messageStats;
  final SubscriptionStats subscriptionStats;
  final Map<String, int> errorStats;
  final PerformanceStats performanceStats;
  final HealthStatus healthStatus;
  
  DiagnosticsReport({
    required this.timestamp,
    required this.connectionStats,
    required this.messageStats,
    required this.subscriptionStats,
    required this.errorStats,
    required this.performanceStats,
    required this.healthStatus,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'connectionStats': connectionStats.toJson(),
      'messageStats': messageStats.toJson(),
      'subscriptionStats': subscriptionStats.toJson(),
      'errorStats': errorStats,
      'performanceStats': performanceStats.toJson(),
      'healthStatus': healthStatus.toJson(),
    };
  }
}

/// Connection statistics
class ConnectionStats {
  final ConnectionState currentState;
  final Map<ConnectionState, int> recentStateChanges;
  final Duration? uptime;
  final int totalReconnects;
  
  ConnectionStats({
    required this.currentState,
    required this.recentStateChanges,
    this.uptime,
    required this.totalReconnects,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'currentState': currentState.name,
      'recentStateChanges': recentStateChanges.map((k, v) => MapEntry(k.name, v)),
      'uptime': uptime?.inSeconds,
      'totalReconnects': totalReconnects,
    };
  }
}

/// Message statistics
class MessageStats {
  final int messagesSent;
  final int messagesReceived;
  final Duration? averageResponseTime;
  final Map<String, int> messagesByAction;
  
  MessageStats({
    required this.messagesSent,
    required this.messagesReceived,
    this.averageResponseTime,
    required this.messagesByAction,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'messagesSent': messagesSent,
      'messagesReceived': messagesReceived,
      'averageResponseTime': averageResponseTime?.inMilliseconds,
      'messagesByAction': messagesByAction,
    };
  }
}

/// Subscription statistics
class SubscriptionStats {
  final int activeSubscriptions;
  final int totalEventsReceived;
  final Map<String, int> subscriptionDetails;
  
  SubscriptionStats({
    required this.activeSubscriptions,
    required this.totalEventsReceived,
    required this.subscriptionDetails,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'activeSubscriptions': activeSubscriptions,
      'totalEventsReceived': totalEventsReceived,
      'subscriptionDetails': subscriptionDetails,
    };
  }
}

/// Performance statistics
class PerformanceStats {
  final Map<String, Duration> averageResponseTimes;
  final DateTime? lastHealthCheck;
  final int memoryUsage;
  
  PerformanceStats({
    required this.averageResponseTimes,
    this.lastHealthCheck,
    required this.memoryUsage,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'averageResponseTimes': averageResponseTimes.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'lastHealthCheck': lastHealthCheck?.toIso8601String(),
      'memoryUsage': memoryUsage,
    };
  }
}

/// Health status
class HealthStatus {
  final String status;
  final DateTime? lastHealthCheck;
  final int recentErrorCount;
  final List<String> issues;
  
  HealthStatus({
    required this.status,
    this.lastHealthCheck,
    required this.recentErrorCount,
    required this.issues,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'lastHealthCheck': lastHealthCheck?.toIso8601String(),
      'recentErrorCount': recentErrorCount,
      'issues': issues,
    };
  }
}

/// Provider for relay diagnostics
final relayDiagnosticsProvider = Provider((ref) => RelayDiagnostics(ref));
