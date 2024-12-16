import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/home/notifiers/home_notifier.dart';
import 'package:mostro_mobile/features/home/notifiers/home_state.dart';


final homeNotifierProvider =
    AsyncNotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

