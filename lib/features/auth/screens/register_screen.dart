import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_button.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

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
        title: const Text('Register', style: TextStyle(color: Colors.white)),
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
                  labelText: 'Private Key (nsec or hex)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePrivateKey
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      ref.read(obscurePrivateKeyProvider.notifier).state =
                          !obscurePrivateKey;
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                obscureText: obscurePrivateKey,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a private key';
                  }
                  if (!value.startsWith('nsec') &&
                      !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
                    return 'Invalid private key format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // PIN Field
              TextFormField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePin ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      ref.read(obscurePinProvider.notifier).state = !obscurePin;
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                obscureText: obscurePin,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a PIN';
                  }
                  if (value.length < 4) {
                    return 'PIN must be at least 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm PIN Field
              TextFormField(
                controller: confirmPinController,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPin
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      ref.read(obscureConfirmPinProvider.notifier).state =
                          !obscureConfirmPin;
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                obscureText: obscureConfirmPin,
                validator: (value) {
                  if (value != pinController.text) {
                    return 'PINs do not match';
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
                        title: const Text('Use Biometrics',
                            style: TextStyle(color: Colors.white)),
                        value: useBiometrics,
                        onChanged: (bool value) {
                          ref.read(useBiometricsProvider.notifier).state =
                              value;
                        },
                        activeColor: Colors.green,
                      )
                    : const SizedBox.shrink();
              }),
              const SizedBox(height: 24),

              // Register Button
              CustomButton(
                text: 'Register',
                onPressed: () => _onRegister(context, ref, formKey,
                    privateKeyController, pinController, useBiometrics),
              ),
              const SizedBox(height: 16),

              // Generate New Key Button
              CustomButton(
                text: 'Generate New Key',
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
