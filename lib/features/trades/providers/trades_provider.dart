import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

final tradesProvider = FutureProvider<List<Session>>((ref) async {
  final sessionManager = ref.read(sessionManagerProvider);
  return sessionManager.sessions;
});
