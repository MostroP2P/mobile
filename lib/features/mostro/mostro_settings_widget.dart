import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

class MostroSettingsWidget extends ConsumerWidget {
  const MostroSettingsWidget({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final settings = ref.watch(settingsProvider);

    throw UnimplementedError();
  }

}