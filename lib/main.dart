import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/home/home.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MostroP2P',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(), // Tu pantalla de inicio
    );
  }
}
