import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_notifier.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';

final tradesProvider = AsyncNotifierProvider<TradesNotifier, TradesState>(
  TradesNotifier.new,
);
