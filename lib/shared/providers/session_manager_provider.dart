
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager();
});
