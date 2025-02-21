import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/custom_button.dart';

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
                      color: AppTheme.cream1,
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
                text: 'REGISTER',
                onPressed: () {
                  context.go('/register');
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: AppTheme.cream1,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
                onPressed: () {
                  context.go('/');
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
