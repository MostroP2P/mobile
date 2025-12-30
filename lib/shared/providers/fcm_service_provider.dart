import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final fcmServiceProvider = Provider<FCMService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FCMService(prefs);
});
