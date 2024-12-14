import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>((ref) {
  // Assume this updated API has an async init method
  // and supports cached operations.
  return SharedPreferencesAsync();
});