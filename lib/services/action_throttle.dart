import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/services/connection_manager.dart';

/// Service to throttle user actions based on network conditions
class ActionThrottle {
  final Ref ref;
  final Logger _logger = Logger();
  
  // Action tracking
  final Map<String, DateTime> _lastActionTimes = {};
  final Map<String, Timer> _pendingActions = {};
  
  // Throttle configuration based on action criticality
  static const Map<Action, Duration> _actionThrottles = {
    // Critical actions - longer throttle to prevent duplicates
    Action.newOrder: Duration(seconds: 5),
    Action.takeBuy: Duration(seconds: 3),
    Action.takeSell: Duration(seconds: 3),
    Action.cancel: Duration(seconds: 2),
    Action.dispute: Duration(seconds: 5),
    Action.release: Duration(seconds: 3),
    
    // Payment actions - moderate throttle
    Action.addInvoice: Duration(seconds: 2),
    Action.fiatSent: Duration(seconds: 2),
    Action.payInvoice: Duration(seconds: 2),
    
    // Low-risk actions - minimal throttle
    Action.rate: Duration(seconds: 1),
    Action.rateUser: Duration(seconds: 1),
  };
  
  // Network-based multipliers
  static const Map<ConnectionState, double> _networkMultipliers = {
    ConnectionState.connected: 1.0,
    ConnectionState.connecting: 2.0,
    ConnectionState.reconnecting: 3.0,
    ConnectionState.failed: 5.0,
    ConnectionState.disconnected: 5.0,
  };
  
  ActionThrottle(this.ref);
  
  /// Check if action is allowed based on throttling rules
  bool canPerformAction(Action action, {String? orderId}) {
    final actionKey = _getActionKey(action, orderId);
    final now = DateTime.now();
    
    // Check if action was performed recently
    final lastActionTime = _lastActionTimes[actionKey];
    if (lastActionTime != null) {
      final throttleDuration = _getThrottleDuration(action);
      final timeSinceLastAction = now.difference(lastActionTime);
      
      if (timeSinceLastAction < throttleDuration) {
        final remainingTime = throttleDuration - timeSinceLastAction;
        _logger.w('Action $action throttled for ${remainingTime.inSeconds}s');
        return false;
      }
    }
    
    return true;
  }
  
  /// Record that an action was performed
  void recordAction(Action action, {String? orderId}) {
    final actionKey = _getActionKey(action, orderId);
    _lastActionTimes[actionKey] = DateTime.now();
    _logger.d('Recorded action: $action for key: $actionKey');
  }
  
  /// Schedule a delayed action if network is unstable
  Future<bool> scheduleAction(
    Action action,
    Future<void> Function() actionCallback, {
    String? orderId,
    Duration? customDelay,
  }) async {
    final actionKey = _getActionKey(action, orderId);
    
    // Cancel any pending action for this key
    _pendingActions[actionKey]?.cancel();
    
    // Check if we can perform immediately
    if (canPerformAction(action, orderId: orderId)) {
      final connectionState = ref.read(connectionManagerProvider).currentState;
      
      if (connectionState == ConnectionState.connected) {
        // Execute immediately if connected
        try {
          await actionCallback();
          recordAction(action, orderId: orderId);
          return true;
        } catch (e) {
          _logger.e('Action $action failed: $e');
          return false;
        }
      } else {
        // Schedule for later if not connected
        final delay = customDelay ?? _getNetworkDelay(connectionState);
        _logger.i('Scheduling action $action for ${delay.inSeconds}s due to network state: $connectionState');
        
        final completer = Completer<bool>();
        _pendingActions[actionKey] = Timer(delay, () async {
          try {
            await actionCallback();
            recordAction(action, orderId: orderId);
            completer.complete(true);
          } catch (e) {
            _logger.e('Scheduled action $action failed: $e');
            completer.complete(false);
          } finally {
            _pendingActions.remove(actionKey);
          }
        });
        
        return completer.future;
      }
    } else {
      _logger.w('Action $action is throttled');
      return false;
    }
  }
  
  /// Get throttle duration for an action based on network conditions
  Duration _getThrottleDuration(Action action) {
    final baseThrottle = _actionThrottles[action] ?? const Duration(seconds: 1);
    final connectionState = ref.read(connectionManagerProvider).currentState;
    final multiplier = _networkMultipliers[connectionState] ?? 1.0;
    
    return Duration(
      milliseconds: (baseThrottle.inMilliseconds * multiplier).round(),
    );
  }
  
  /// Get network-based delay for scheduling actions
  Duration _getNetworkDelay(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return Duration.zero;
      case ConnectionState.connecting:
        return const Duration(seconds: 2);
      case ConnectionState.reconnecting:
        return const Duration(seconds: 5);
      case ConnectionState.failed:
      case ConnectionState.disconnected:
        return const Duration(seconds: 10);
    }
  }
  
  /// Generate unique key for action tracking
  String _getActionKey(Action action, String? orderId) {
    return orderId != null ? '${action.name}_$orderId' : action.name;
  }
  
  /// Get remaining throttle time for an action
  Duration? getRemainingThrottleTime(Action action, {String? orderId}) {
    final actionKey = _getActionKey(action, orderId);
    final lastActionTime = _lastActionTimes[actionKey];
    
    if (lastActionTime == null) return null;
    
    final throttleDuration = _getThrottleDuration(action);
    final timeSinceLastAction = DateTime.now().difference(lastActionTime);
    
    if (timeSinceLastAction < throttleDuration) {
      return throttleDuration - timeSinceLastAction;
    }
    
    return null;
  }
  
  /// Check if action is currently pending
  bool isActionPending(Action action, {String? orderId}) {
    final actionKey = _getActionKey(action, orderId);
    return _pendingActions.containsKey(actionKey);
  }
  
  /// Cancel pending action
  void cancelPendingAction(Action action, {String? orderId}) {
    final actionKey = _getActionKey(action, orderId);
    final timer = _pendingActions.remove(actionKey);
    timer?.cancel();
    _logger.d('Cancelled pending action: $actionKey');
  }
  
  /// Get throttle statistics
  ThrottleStats getStats() {
    final now = DateTime.now();
    final activeThrottles = <String, Duration>{};
    
    for (final entry in _lastActionTimes.entries) {
      final actionKey = entry.key;
      final lastTime = entry.value;
      
      // Extract action from key
      final actionName = actionKey.split('_').first;
      final action = Action.values.firstWhere(
        (a) => a.name == actionName,
        orElse: () => Action.newOrder,
      );
      
      final throttleDuration = _getThrottleDuration(action);
      final timeSinceLastAction = now.difference(lastTime);
      
      if (timeSinceLastAction < throttleDuration) {
        activeThrottles[actionKey] = throttleDuration - timeSinceLastAction;
      }
    }
    
    return ThrottleStats(
      activeThrottles: activeThrottles,
      pendingActions: _pendingActions.keys.toList(),
      totalActionsTracked: _lastActionTimes.length,
    );
  }
  
  /// Clear all throttle state
  void clearThrottleState() {
    _lastActionTimes.clear();
    
    // Cancel all pending actions
    for (final timer in _pendingActions.values) {
      timer.cancel();
    }
    _pendingActions.clear();
    
    _logger.i('Cleared action throttle state');
  }
  
  void dispose() {
    clearThrottleState();
  }
}

/// Throttle statistics
class ThrottleStats {
  final Map<String, Duration> activeThrottles;
  final List<String> pendingActions;
  final int totalActionsTracked;
  
  ThrottleStats({
    required this.activeThrottles,
    required this.pendingActions,
    required this.totalActionsTracked,
  });
}

/// Provider for action throttle
final actionThrottleProvider = Provider((ref) => ActionThrottle(ref));
