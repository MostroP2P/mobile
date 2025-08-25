import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final database = ref.watch(mostroDatabaseProvider);
  return NotificationsStorage(db: database);
});