import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/images/mostro-icons.png',
                height: 200,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              Text(
                'NO-KYC P2P Lightning\nexchange on top of\nnostr',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Peer-to-peer Lightning Network platform over nostr',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.grey2),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              CustomButton(
                text: 'START TESTING',
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/');
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
