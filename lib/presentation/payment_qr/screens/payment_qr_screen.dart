import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../bloc/payment_qr_bloc.dart';
import '../bloc/payment_qr_event.dart';
import '../bloc/payment_qr_state.dart';
import '../../widgets/bottom_nav_bar.dart';

class PaymentQrScreen extends StatelessWidget {
  const PaymentQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentQrBloc()..add(LoadPaymentQr()),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('PAYMENT'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<PaymentQrBloc, PaymentQrState>(
          builder: (context, state) {
            if (state is PaymentQrLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is PaymentQrLoaded) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Pay this invoice to continue the exchange',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  QrImage(
                    data: state.qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Expires in: ${state.expiresIn}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8CC541),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      context.read<PaymentQrBloc>().add(OpenWallet());
                    },
                    child: const Text('OPEN WALLET'),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    child:
                        const Text('CANCEL', style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            } else if (state is PaymentQrError) {
              return Center(child: Text(state.error));
            } else {
              return const Center(child: Text('Something went wrong'));
            }
          },
        ),
        bottomNavigationBar: const BottomNavBar(),
      ),
    );
  }
}
