import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_state.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/data/enums.dart';

class NotificationsNotifier extends StateNotifier<TemporaryNotificationsState> {
  final Ref ref;
  late final NotificationsRepository _repository;
  
  NotificationsNotifier(this.ref) : super(const TemporaryNotificationsState(
    temporaryNotification: TemporaryNotification(),
  )) {
    _repository = ref.read(notificationsRepositoryProvider);
  }


  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
  }


  Future<void> addNotification(NotificationModel notification) async {
    await _repository.addNotification(notification);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
  }

  void showTemporary(Action action, {Map<String, dynamic> values = const {}}) {
    state = state.copyWith(
      temporaryNotification: TemporaryNotification(
        action: action,
        values: values,
        show: true,
      ),
    );
  }

  void showCustomMessage(String message) {
    state = state.copyWith(
      temporaryNotification: TemporaryNotification(
        customMessage: message,
        show: true,
      ),
    );
  }

  void clearTemporary() {
    state = state.copyWith(
      temporaryNotification: const TemporaryNotification(),
    );
  }

  Future<void> addToHistory(Action action, {Map<String, dynamic> values = const {}, String? orderId, String? eventId}) async {
    final notificationId = _generateDeterministicId(action, orderId, values, eventId);
    
    final notification = NotificationModel(
      id: notificationId,
      type: NotificationModel.getNotificationTypeFromAction(action),
      action: action,
      title: NotificationMessageMapper.getTitleKey(action),
      message: NotificationMessageMapper.getMessageKey(action),
      timestamp: DateTime.now(),
      orderId: orderId,
      data: values,
    );
    await addNotification(notification);
  }
  
  String _generateDeterministicId(Action action, String? orderId, Map<String, dynamic> values, String? eventId) {
    // Create deterministic ID based on content
    final content = {
      'action': action.name,
      'orderId': orderId ?? '',
      'values': values,
      'eventId': eventId ?? '',
    };
    
    // Sort keys for deterministic serialization
    final sortedContent = Map.fromEntries(
      content.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    final contentString = jsonEncode(sortedContent);
    final bytes = utf8.encode(contentString);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  Future<void> notify(Action action, {Map<String, dynamic> values = const {}, String? orderId, String? eventId}) async {
    // Generate deterministic ID to check for duplicates
    final notificationId = _generateDeterministicId(action, orderId, values, eventId);
    
    // Check if notification already exists in database
    final alreadyExists = await _repository.notificationExists(notificationId);
    
    if (alreadyExists) {
      // Show temporary notification but don't add to history
      showTemporary(action, values: values);
      return;
    }
    
    // Not a duplicate, proceed with normal notification
    showTemporary(action, values: values);
    await addToHistory(action, values: values, orderId: orderId, eventId: eventId);
  }


}