import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';

class LogsRecordingIndicator extends ConsumerStatefulWidget {
  const LogsRecordingIndicator({super.key});

  @override
  ConsumerState<LogsRecordingIndicator> createState() =>
      _LogsRecordingIndicatorState();
}

class _LogsRecordingIndicatorState
    extends ConsumerState<LogsRecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isLoggingEnabled = settings.isLoggingEnabled;

    if (!isLoggingEnabled) {
      return const SizedBox.shrink();
    }

    final currentRoute = GoRouterState.of(context).uri.path;
    final isOnLogsScreen = currentRoute == '/logs';

    if (isOnLogsScreen) {
      return const SizedBox.shrink();
    }

    final isDrawerOpen = ref.watch(drawerProvider);
    final hasBottomNavBar = currentRoute == '/' ||
        currentRoute == '/order_book' ||
        currentRoute == '/chat_list';

    final bottomOffset = isDrawerOpen ? 10.0 : (hasBottomNavBar ? 90.0 : 10.0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      bottom: MediaQuery.of(context).padding.bottom + bottomOffset,
      left: 16,
      child: GestureDetector(
        onTap: () => context.push('/logs'),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.statusError.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.statusError
                        .withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.statusError
                            .withValues(alpha: _pulseAnimation.value * 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
