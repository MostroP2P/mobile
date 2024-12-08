import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/notifiers/nostr_service_notifier.dart';

class OpenOrdersRepositoryNotifier extends AsyncNotifier<OpenOrdersRepository> {
  @override
  Future<OpenOrdersRepository> build() async {
    final nostrService = await ref.watch(nostrServiceProvider.future);
    return OpenOrdersRepository(nostrService);
  }
}

