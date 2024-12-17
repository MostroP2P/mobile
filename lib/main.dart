import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nostrService = NostrService();
  await nostrService.init();
  final biometricsHelper = BiometricsHelper();

  runApp(
    ProviderScope(
      overrides: [
        nostrServicerProvider.overrideWithValue(nostrService),
        biometricsHelperProvider.overrideWithValue(biometricsHelper),
      ],
      child: const MostroApp(),
    ),
  );
}
