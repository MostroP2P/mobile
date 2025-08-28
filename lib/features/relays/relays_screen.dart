import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';

class RelaysScreen extends ConsumerWidget {
  const RelaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Configuración',
          style: TextStyle(
            color: AppTheme.cream1,
          ),
        ),
      ),
      backgroundColor: AppTheme.dark1,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: RelaySelector(),
      ),
    );
  }
}
