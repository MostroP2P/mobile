import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddOrderButton extends StatelessWidget {
  const AddOrderButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom:
          100, // Ajusta según sea necesario para que quede encima del navbar
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF8CC541), // Verde como en la imagen
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/add_order'); // Ruta para agregar nueva orden
            },
            borderRadius: BorderRadius.circular(
                28), // Para que el efecto del tap sea circular
            child: const Center(
              child: Icon(
                Icons.add,
                color: Colors.black,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
