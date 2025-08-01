import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/drawer_provider.dart';
import 'package:mostro_mobile/shared/widgets/notification_history_bell_widget.dart';
import 'dart:async';

/// Animated Mostro logo widget that shows normal logo and switches to happy logo on tap
class AnimatedMostroLogo extends StatefulWidget {
  const AnimatedMostroLogo({super.key});

  @override
  State<AnimatedMostroLogo> createState() => _AnimatedMostroLogoState();
}

class _AnimatedMostroLogoState extends State<AnimatedMostroLogo> {
  bool _isHappy = false;
  Timer? _timer;

  void _onTap() {
    if (_timer?.isActive == true) {
      return; // Prevent multiple taps during animation
    }

    setState(() {
      _isHappy = true;
    });

    _timer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isHappy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Image.asset(
          _isHappy
              ? 'assets/images/mostro-happy-100.png'
              : 'assets/images/mostro-100.png',
          key: ValueKey(_isHappy),
          height: 32,
          width: 32,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class MostroAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showBackButton;
  final bool showDrawerButton;
  final List<Widget>? actions;
  
  const MostroAppBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.showDrawerButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine what to show in the leading position
    Widget? leading;
    if (showBackButton) {
      leading = Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: IconButton(
          icon: const HeroIcon(
            HeroIcons.arrowLeft,
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 28,
          ),
          onPressed: () => context.pop(),
        ),
      );
    } else if (showDrawerButton) {
      leading = Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: IconButton(
          icon: const HeroIcon(
            HeroIcons.bars3,
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 28,
          ),
          onPressed: () => ref.read(drawerProvider.notifier).toggleDrawer(),
        ),
      );
    }
    
    // Use provided actions or default to just notification bell
    List<Widget> appBarActions = actions ?? [
      const NotificationBellWidget(),
      const SizedBox(width: 16),
    ];
    
    return AppBar(
      backgroundColor: AppTheme.backgroundDark,
      elevation: 0,
      leadingWidth: 70,
      title: title ?? const AnimatedMostroLogo(),
      centerTitle: true,
      // Add bottom border similar to bottom navbar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          height: 1.0,
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      leading: leading,
      actions: appBarActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}
