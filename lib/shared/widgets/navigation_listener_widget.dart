import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/notifiers/navigation_notifier.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';

class NavigationListenerWidget extends ConsumerWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigator;

  const NavigationListenerWidget(
      {super.key, required this.child, required this.navigator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NavigationState>(navigationProvider, (previous, next) {
      navigator.currentState!.push(
        MaterialPageRoute(
          builder: next.widgetBuilder!,
        ),
      );
    });

    // Ensure the rest of the widget tree is displayed
    return child;
  }
}
