import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupConfirmationNotifier extends StateNotifier<bool> {
  static const String _confirmedSavedKey = 'user_confirmed_saved_mnemonic';
  
  BackupConfirmationNotifier() : super(false) {
    _loadConfirmationState();
  }

  Future<void> _loadConfirmationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConfirmed = prefs.getBool(_confirmedSavedKey) ?? false;
      state = isConfirmed;
    } catch (e) {
      state = false;
    }
  }

  Future<void> setBackupConfirmed(bool confirmed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_confirmedSavedKey, confirmed);
      state = confirmed;
    } catch (e) {
      // Handle error if needed
    }
  }
}

final backupConfirmationProvider = StateNotifierProvider<BackupConfirmationNotifier, bool>((ref) {
  return BackupConfirmationNotifier();
});