import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/services/connection_manager.dart';
import 'package:mostro_mobile/shared/providers.dart';

/// Message buffer for reliable message delivery with retry logic
class MessageBuffer {
  final Ref ref;
  final Logger _logger = Logger();
  
  // Pending messages queue
  final List<PendingMessage> _pendingMessages = [];
  final Map<String, Completer<bool>> _messageCompleters = {};
  
  // Configuration
  static const int maxRetries = 5;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration messageTimeout = Duration(minutes: 2);
  
  // Cleanup timer
  Timer? _cleanupTimer;
  
  MessageBuffer(this.ref) {
    _startCleanupTimer();
    _listenToConnectionState();
  }
  
  /// Listen to connection state changes to process pending messages
  void _listenToConnectionState() {
    ref.read(connectionManagerInstanceProvider).connectionState.listen((state) {
      if (state == ConnectionState.connected) {
        _processPendingMessages();
      }
    });
  }
  
  /// Buffer a message for reliable delivery
  Future<bool> bufferMessage(MostroMessage message, {
    int priority = 0,
    Duration? timeout,
  }) async {
    final messageId = _generateMessageId();
    final pendingMessage = PendingMessage(
      id: messageId,
      message: message,
      priority: priority,
      createdAt: DateTime.now(),
      timeout: timeout ?? messageTimeout,
      retryCount: 0,
    );
    
    _pendingMessages.add(pendingMessage);
    _sortMessagesByPriority();
    
    final completer = Completer<bool>();
    _messageCompleters[messageId] = completer;
    
    _logger.i('Buffered message: ${message.action} for order: ${message.id}');
    
    // Try to send immediately if connected
    if (ref.read(connectionManagerProvider) == ConnectionState.connected) {
      _processPendingMessages();
    }
    
    return completer.future;
  }
  
  /// Process all pending messages
  Future<void> _processPendingMessages() async {
    if (_pendingMessages.isEmpty) return;
    
    _logger.i('Processing ${_pendingMessages.length} pending messages');
    
    final messagesToProcess = List<PendingMessage>.from(_pendingMessages);
    
    for (final pendingMessage in messagesToProcess) {
      if (ref.read(connectionManagerProvider) != ConnectionState.connected) {
        _logger.w('Connection lost while processing messages');
        break;
      }
      
      await _attemptMessageDelivery(pendingMessage);
    }
  }
  
  /// Attempt to deliver a single message
  Future<void> _attemptMessageDelivery(PendingMessage pendingMessage) async {
    try {
      _logger.d('Attempting delivery of message: ${pendingMessage.id}');
      
      // Check if message has timed out
      if (DateTime.now().difference(pendingMessage.createdAt) > pendingMessage.timeout) {
        _logger.w('Message ${pendingMessage.id} timed out');
        _completeMessage(pendingMessage.id, false);
        return;
      }
      
      // Attempt to publish the message
      final success = await _publishMessage(pendingMessage.message);
      
      if (success) {
        _logger.i('Successfully delivered message: ${pendingMessage.id}');
        _completeMessage(pendingMessage.id, true);
      } else {
        _handleDeliveryFailure(pendingMessage);
      }
      
    } catch (e) {
      _logger.e('Error delivering message ${pendingMessage.id}: $e');
      _handleDeliveryFailure(pendingMessage);
    }
  }
  
  /// Publish message through MostroService
  Future<bool> _publishMessage(MostroMessage message) async {
    try {
      final mostroService = ref.read(mostroServiceProvider);
      await mostroService.publishOrder(message);
      return true;
    } catch (e) {
      _logger.e('Failed to publish message: $e');
      return false;
    }
  }
  
  /// Handle message delivery failure
  void _handleDeliveryFailure(PendingMessage pendingMessage) {
    pendingMessage.retryCount++;
    
    if (pendingMessage.retryCount >= maxRetries) {
      _logger.e('Message ${pendingMessage.id} failed after ${pendingMessage.retryCount} attempts');
      _completeMessage(pendingMessage.id, false);
    } else {
      _logger.w('Message ${pendingMessage.id} failed, will retry (${pendingMessage.retryCount}/$maxRetries)');
      
      // Schedule retry with delay
      Timer(retryDelay, () {
        if (_pendingMessages.any((m) => m.id == pendingMessage.id)) {
          _attemptMessageDelivery(pendingMessage);
        }
      });
    }
  }
  
  /// Complete message delivery
  void _completeMessage(String messageId, bool success) {
    _pendingMessages.removeWhere((m) => m.id == messageId);
    
    final completer = _messageCompleters.remove(messageId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }
  
  /// Sort messages by priority (higher priority first)
  void _sortMessagesByPriority() {
    _pendingMessages.sort((a, b) => b.priority.compareTo(a.priority));
  }
  
  /// Start cleanup timer for expired messages
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredMessages();
    });
  }
  
  /// Clean up expired messages
  void _cleanupExpiredMessages() {
    final now = DateTime.now();
    final expiredMessages = _pendingMessages.where((m) => 
        now.difference(m.createdAt) > m.timeout).toList();
    
    for (final expired in expiredMessages) {
      _logger.w('Cleaning up expired message: ${expired.id}');
      _completeMessage(expired.id, false);
    }
  }
  
  /// Generate unique message ID
  String _generateMessageId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_pendingMessages.length}';
  }
  
  /// Get buffer statistics
  BufferStats getStats() {
    return BufferStats(
      pendingCount: _pendingMessages.length,
      oldestMessage: _pendingMessages.isEmpty ? null : 
          _pendingMessages.map((m) => m.createdAt).reduce((a, b) => a.isBefore(b) ? a : b),
      priorityDistribution: _getPriorityDistribution(),
    );
  }
  
  /// Get priority distribution
  Map<int, int> _getPriorityDistribution() {
    final distribution = <int, int>{};
    for (final message in _pendingMessages) {
      distribution[message.priority] = (distribution[message.priority] ?? 0) + 1;
    }
    return distribution;
  }
  
  /// Clear all pending messages
  void clearBuffer() {
    _logger.i('Clearing message buffer (${_pendingMessages.length} messages)');
    
    for (final message in _pendingMessages) {
      _completeMessage(message.id, false);
    }
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    clearBuffer();
  }
}

/// Pending message wrapper
class PendingMessage {
  final String id;
  final MostroMessage message;
  final int priority;
  final DateTime createdAt;
  final Duration timeout;
  int retryCount;
  
  PendingMessage({
    required this.id,
    required this.message,
    required this.priority,
    required this.createdAt,
    required this.timeout,
    this.retryCount = 0,
  });
}

/// Buffer statistics
class BufferStats {
  final int pendingCount;
  final DateTime? oldestMessage;
  final Map<int, int> priorityDistribution;
  
  BufferStats({
    required this.pendingCount,
    this.oldestMessage,
    required this.priorityDistribution,
  });
}

/// Message priorities
class MessagePriority {
  static const int critical = 100;  // Disputes, cancellations
  static const int high = 75;      // Payment confirmations, releases
  static const int normal = 50;    // Order creation, takes
  static const int low = 25;       // Ratings, non-critical updates
}

/// Provider for message buffer
final messageBufferProvider = Provider((ref) => MessageBuffer(ref));
