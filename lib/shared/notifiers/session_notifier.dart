import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/session_manager.dart';

class SessionNotifier extends StateNotifier<List<Session>> {
  final SessionManager _manager;

  SessionNotifier(this._manager) : super(_manager.sessions);

  Future<Session> newSession({String? orderId}) async {
    final session = await _manager.newSession(orderId: orderId);
    state = _manager.sessions;
    return session;
  }

  Future<void> saveSession(Session session) async {
    await _manager.saveSession(session);
    state = _manager.sessions;
  }

  Future<void> deleteSession(int sessionId) async {
    await _manager.deleteSession(sessionId);
    state = _manager.sessions;
  }

  Session? getSessionByOrderId(String orderId) {
    return _manager.getSessionByOrderId(orderId);
  }

  Future<Session?> loadSession(int keyIndex) async {
    final s = await _manager.loadSession(keyIndex);
    state = _manager.sessions;
    return s;
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
