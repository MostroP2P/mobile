import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../widgets/custom_button.dart';
import '../../../core/utils/nostr_utils.dart';
import '../../../core/routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _privateKeyController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePrivateKey = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _useBiometrics = false;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthCheckBiometricsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1D212C),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthBiometricsAvailability) {
            setState(() {
              _biometricsAvailable = state.isAvailable;
            });
          } else if (state is AuthKeyGenerated) {
            setState(() {
              _privateKeyController.text =
                  NostrUtils.nsecToHex(state.privateKey);
            });
          } else if (state is AuthRegistrationSuccess) {
            // Navegar al home después de un registro exitoso
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _privateKeyController,
                    decoration: InputDecoration(
                      labelText: 'Private Key (nsec or hex)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePrivateKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePrivateKey = !_obscurePrivateKey;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscurePrivateKey,
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
                  TextFormField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePin = !_obscurePin;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
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
                  TextFormField(
                    controller: _confirmPinController,
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPin
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPin = !_obscureConfirmPin;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    obscureText: _obscureConfirmPin,
                    validator: (value) {
                      if (value != _pinController.text) {
                        return 'PINs do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_biometricsAvailable)
                    SwitchListTile(
                      title: const Text('Use Biometrics',
                          style: TextStyle(color: Colors.white)),
                      value: _useBiometrics,
                      onChanged: (bool value) {
                        setState(() {
                          _useBiometrics = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Register',
                    onPressed: _onRegister,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Generate New Key',
                    onPressed: () {
                      context.read<AuthBloc>().add(AuthGenerateKeyRequested());
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            AuthRegisterRequested(
              _privateKeyController.text,
              _pinController.text,
              _useBiometrics,
            ),
          );
    }
  }
}
