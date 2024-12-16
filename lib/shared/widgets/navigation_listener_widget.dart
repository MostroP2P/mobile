import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/shared/notifiers/navigation_notifier.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';

class NavigationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NavigationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NavigationState>(navigationProvider, (previous, next) {
      if (next.path.isNotEmpty) {
        context.go(next.path);
      }
    });
    return child;
  }
}
