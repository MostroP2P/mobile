import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationState {
  final WidgetBuilder? widgetBuilder;

  NavigationState({required this.widgetBuilder});
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier()
      : super(NavigationState(widgetBuilder: null));

  void navigate(WidgetBuilder builder) {
    state = NavigationState(widgetBuilder: builder);
  }
}
