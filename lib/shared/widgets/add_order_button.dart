import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddOrderButton extends StatelessWidget {
  const AddOrderButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Creating a FloatingActionButton for perfect roundness
    return FloatingActionButton(
      onPressed: () => context.push('/add_order'),
      backgroundColor: const Color(0xFF8CC541), // Mostro green
      elevation: 6,
      shape: const CircleBorder(), // Ensuring perfect roundness
      child: const Icon(
        Icons.add,
        color: Colors.black,
        size: 28,
      ),
    );
  }
}
