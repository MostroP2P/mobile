import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';

class TradesNotifier extends AsyncNotifier<TradesState> {
  @override
  FutureOr<TradesState> build() async {
    state = const AsyncLoading();

    return TradesState([]);
  }
}
