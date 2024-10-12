import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../bloc/payment_qr_bloc.dart';
import '../bloc/payment_qr_event.dart';
import '../bloc/payment_qr_state.dart';
import '../../widgets/bottom_nav_bar.dart';

class PaymentQrScreen extends StatelessWidget {
  const PaymentQrScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentQrBloc()..add(LoadPaymentQr()),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('PAYMENT'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<PaymentQrBloc, PaymentQrState>(
          builder: (context, state) {
            if (state is PaymentQrLoading) {
              return Center(child: CircularProgressIndicator());
            } else if (state is PaymentQrLoaded) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pay this invoice to continue the exchange',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  QrImage(
                    data: state.qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: Colors.white,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Expires in: ${state.expiresIn}',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    child: Text('OPEN WALLET'),
                    style: ElevatedButton.styleFrom(
                      primary: Color(0xFF8CC541),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      context.read<PaymentQrBloc>().add(OpenWallet());
                    },
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    child:
                        Text('CANCEL', style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            } else if (state is PaymentQrError) {
              return Center(child: Text(state.error));
            } else {
              return Center(child: Text('Something went wrong'));
            }
          },
        ),
        bottomNavigationBar: BottomNavBar(),
      ),
    );
  }
}
