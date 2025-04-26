import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  final keyManager = ref.read(keyManagerProvider);
  final database = ref.read(mostroDatabaseProvider);
  return SessionStorage(keyManager, db: database);
});

/// Stream provider for watching a single session by ID
final sessionProvider = StreamProvider.family<Session?, String>((ref, orderId) {
  final storage = ref.read(sessionStorageProvider);
  return storage.watchSession(orderId);
});

/// Stream provider for watching all sessions
final allSessionsProvider = StreamProvider<List<Session>>((ref) {
  final storage = ref.read(sessionStorageProvider);
  return storage.watchAllSessions();
});

/// Stream provider for watching active/non-expired sessions
final activeSessionsProvider = StreamProvider<List<Session>>((ref) {
  final storage = ref.read(sessionStorageProvider);
  // Default to 48 hours as session expiration time
  return storage.watchActiveSessions(48);
});
