import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_button.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize controllers using hooks
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final privateKeyController = useTextEditingController();
    final pinController = useTextEditingController();
    final confirmPinController = useTextEditingController();

    // UI-specific state managed via StateProviders
    final obscurePrivateKey = ref.watch(obscurePrivateKeyProvider);
    final obscurePin = ref.watch(obscurePinProvider);
    final obscureConfirmPin = ref.watch(obscureConfirmPinProvider);
    final useBiometrics = ref.watch(useBiometricsProvider);

    // Listen to AuthState changes for side effects
    ref.listen<AuthState>(authNotifierProvider, (previous, state) {
      if (state is AuthKeyGenerated) {
        privateKeyController.text = NostrUtils.nsecToHex(state.privateKey);
      } else if (state is AuthRegistrationSuccess) {
        // Navigate to home after successful registration
        context.go('/');
      } else if (state is AuthFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error)),
        );
      }
    });

    // Trigger biometrics check on first build
    useEffect(() {
      ref.read(authNotifierProvider.notifier).checkBiometrics();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.register,
            style: const TextStyle(color: AppTheme.cream1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1D212C),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Private Key Field
              TextFormField(
                controller: privateKeyController,
                decoration: InputDecoration(
                  labelText: S.of(context)!.privateKeyLabel,
                  labelStyle: const TextStyle(color: AppTheme.cream1),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cream1),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePrivateKey
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.cream1,
                    ),
                    onPressed: () {
                      ref.read(obscurePrivateKeyProvider.notifier).state =
                          !obscurePrivateKey;
                    },
                  ),
                ),
                style: const TextStyle(color: AppTheme.cream1),
                obscureText: obscurePrivateKey,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context)!.pleaseEnterPrivateKey;
                  }
                  if (!value.startsWith('nsec') &&
                      !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
                    return S.of(context)!.invalidPrivateKeyFormat;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // PIN Field
              TextFormField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: S.of(context)!.pin,
                  labelStyle: const TextStyle(color: AppTheme.cream1),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cream1),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePin ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.cream1,
                    ),
                    onPressed: () {
                      ref.read(obscurePinProvider.notifier).state = !obscurePin;
                    },
                  ),
                ),
                style: const TextStyle(color: AppTheme.cream1),
                keyboardType: TextInputType.number,
                obscureText: obscurePin,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context)!.pleaseEnterPin;
                  }
                  if (value.length < 4) {
                    return S.of(context)!.pinMustBeAtLeast4Digits;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm PIN Field
              TextFormField(
                controller: confirmPinController,
                decoration: InputDecoration(
                  labelText: S.of(context)!.confirmPin,
                  labelStyle: const TextStyle(color: AppTheme.cream1),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cream1),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPin
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.cream1,
                    ),
                    onPressed: () {
                      ref.read(obscureConfirmPinProvider.notifier).state =
                          !obscureConfirmPin;
                    },
                  ),
                ),
                style: const TextStyle(color: AppTheme.cream1),
                keyboardType: TextInputType.number,
                obscureText: obscureConfirmPin,
                validator: (value) {
                  if (value != pinController.text) {
                    return S.of(context)!.pinsDoNotMatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Biometrics Toggle (if available)
              Consumer(builder: (context, ref, _) {
                final authState = ref.watch(authNotifierProvider);
                bool biometricsAvailable = false;
                if (authState is AuthBiometricsAvailability) {
                  biometricsAvailable = authState.isAvailable;
                }
                return biometricsAvailable
                    ? SwitchListTile(
                        title: Text(S.of(context)!.useBiometrics,
                            style: const TextStyle(color: AppTheme.cream1)),
                        value: useBiometrics,
                        onChanged: (bool value) {
                          ref.read(useBiometricsProvider.notifier).state =
                              value;
                        },
                        activeThumbColor: AppTheme.activeColor,
                      )
                    : const SizedBox.shrink();
              }),
              const SizedBox(height: 24),

              // Register Button
              CustomButton(
                text: S.of(context)!.register,
                onPressed: () => _onRegister(context, ref, formKey,
                    privateKeyController, pinController, useBiometrics),
              ),
              const SizedBox(height: 16),

              // Generate New Key Button
              CustomButton(
                text: S.of(context)!.generateNewKey,
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).generateKey(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles the registration process
  void _onRegister(
    BuildContext context,
    WidgetRef ref,
    GlobalKey<FormState> formKey,
    TextEditingController privateKeyController,
    TextEditingController pinController,
    bool useBiometrics,
  ) {
    if (formKey.currentState!.validate()) {
      final privateKey = privateKeyController.text;
      final pin = pinController.text;

      ref.read(authNotifierProvider.notifier).register(
            privateKey: privateKey,
            password: pin,
            useBiometrics: useBiometrics,
          );
    }
  }
}
