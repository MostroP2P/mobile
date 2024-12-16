import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationState {
  final String path;

  NavigationState(this.path);
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(NavigationState('/'));

  void go(String path) {
    state = NavigationState(path);
  }
}
