import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/notifiers/nostr_service_notifier.dart';

class OpenOrdersRepositoryNotifier extends AsyncNotifier<OpenOrdersRepository> {
  @override
  Future<OpenOrdersRepository> build() async {
    final nostrService = ref.watch(nostrServiceProvider);
    return OpenOrdersRepository(nostrService);
  }
}

