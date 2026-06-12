import 'package:flutter_riverpod/legacy.dart';
import 'package:mostro_mobile/shared/notifiers/navigation_notifier.dart';

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>(
        (ref) => NavigationNotifier());
