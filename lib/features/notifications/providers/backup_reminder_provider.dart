import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

class BackupReminderNotifier extends StateNotifier<bool> {
  static const String _backupReminderKey = 'backup_reminder_dismissed';
  final SharedPreferencesAsync _prefs;

  BackupReminderNotifier(this._prefs) : super(false) {
    _loadBackupReminderState();
  }

  Future<void> _loadBackupReminderState() async {
    // If the backup reminder was dismissed, state should be false
    // If it was never dismissed (or new user), state should be true
    final isDismissed = await _prefs.getBool(_backupReminderKey) ?? false;
    state = !isDismissed;
  }

  /// Shows the backup reminder (called on first app launch or new user creation)
  Future<void> showBackupReminder() async {
    await _prefs.setBool(_backupReminderKey, false);
    state = true;
  }

  /// Dismisses the backup reminder (called when user views seed phrase)
  Future<void> dismissBackupReminder() async {
    await _prefs.setBool(_backupReminderKey, true);
    state = false;
  }

  /// Checks if the backup reminder should be shown
  bool get shouldShowBackupReminder => state;
}

final backupReminderProvider = StateNotifierProvider<BackupReminderNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupReminderNotifier(prefs);
});