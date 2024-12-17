import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/notifiers/navigation_notifier.dart';

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>(
        (ref) => NavigationNotifier());
