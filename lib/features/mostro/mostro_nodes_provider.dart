import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_notifier.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final mostroNodesProvider =
    StateNotifierProvider<MostroNodesNotifier, List<MostroNode>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MostroNodesNotifier(prefs, ref);
});
