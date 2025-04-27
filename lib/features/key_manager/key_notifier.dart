import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

class KeyNotifier extends StateNotifier<NostrKeyPairs?> {
  final KeyManager _keyManager;
  final Settings _settings;

  KeyNotifier(this._keyManager, this._settings)
      : super(_keyManager.masterKeyPair);
}
