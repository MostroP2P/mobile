import 'package:mostro_mobile/common/top_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_button.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final pinController = useTextEditingController();

    ref.listen<AuthState>(authNotifierProvider, (previous, state) {
      if (state is AuthAuthenticated) {
        context.go('/');
      } else if (state is AuthFailure) {
        showTopSnackBar(
          context,
          state.error,
          );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.login,
            style: const TextStyle(color: AppTheme.cream1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1D212C),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: S.of(context)!.pin,
                  labelStyle: TextStyle(color: AppTheme.cream1),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cream1),
                  ),
                ),
                style: const TextStyle(color: AppTheme.cream1),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context)!.pleaseEnterPin;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: S.of(context)!.login,
                onPressed: () => _onLogin(context, ref, formKey, pinController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onLogin(
    BuildContext context,
    WidgetRef ref,
    GlobalKey<FormState> formKey,
    TextEditingController pinController,
  ) {
    if (formKey.currentState!.validate()) {
      final pin = pinController.text;

      ref.read(authNotifierProvider.notifier).login(
            password: pin,
          );
    }
  }
}
