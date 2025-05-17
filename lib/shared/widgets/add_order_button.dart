import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class AddOrderButton extends StatelessWidget {
  const AddOrderButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.push('/add_order'),
      backgroundColor: AppTheme.activeColor,
      elevation: 6,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.add,
        color: Colors.black,
        size: 28,
      ),
    );
  }
}
