import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app.dart';
import 'package:mostro_mobile/providers/riverpod_providers.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nostrService = NostrService();
  await nostrService.init();

  final biometricsHelper = BiometricsHelper();

  runApp(
    ProviderScope(
      overrides: [
        biometricsHelperProvider.overrideWithValue(biometricsHelper),
      ],
      child: const MostroApp(),
    ),
  );
}
